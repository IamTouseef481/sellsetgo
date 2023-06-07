defmodule SellSetGoApiWeb.MVLController do
  use SellSetGoApiWeb, :controller

  alias SellSetGoApi.Inventory.{Products, VariationProducts, Data, Mvl}
  alias SellSetGoApi.Offers.{VariationOffers, Offers}
  alias SellSetGoApi.{Configurations, Listings, OauthEbay, Utils}

  action_fallback(SellSetGoApiWeb.FallbackController)

  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "draft"} = params
      ) do
    params = Map.put(params, "user_id", current_session_record.user_id)

    with {:ok, _} <- validate_variant_skus(params),
         {:ok, _} <- VariationProducts.create_product_and_offer(params, current_session_record) do
      conn
      |> render("message.json", message: "Inventory items drafted")
    else
      {:error, _, msg, _} -> {:error, msg}
      {:error, "Invalid SKUs"} = error -> error
      {:error, _} -> {:error, "Error while updating on SSG"}
    end
  end

  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "submit"} = params
      ) do
    params = Map.put(params, "user_id", current_session_record.user_id)
    marketplace_id = List.first(params["variation_offers"])["marketplace_id"]

    with {:ok, _} <- validate_variant_skus(params),
         {:ok,
          %{
            create_product: product,
            create_offer: _offer,
            create_variation_products: vp,
            create_variation_offers: vo
          }} <-
           VariationProducts.create_product_and_offer(params, current_session_record),
         :ok <-
           Enum.each(
             [%{sku: product.sku, image_ids: product.image_ids} | vp],
             &Listings.update_provider_image_url(&1.image_ids, current_session_record, &1.sku)
           ),
         {:ok, %OAuth2.Response{body: _body}} <-
           ebay_bulk_create_or_update_inventory(
             product,
             vp,
             marketplace_id,
             current_session_record
           ),
         {:ok, %OAuth2.Response{body: _body}} <-
           group_inventory_items(product, marketplace_id, params, current_session_record),
         {:ok, _product} <- Products.update_product(product, %{"is_submitted" => true}),
         _ <- VariationProducts.submit_products(product.variant_skus, current_session_record),
         {:ok, offer_ids} <-
           ebay_create_offers(params, vo, product, marketplace_id, current_session_record),
         {:ok, response} <-
           get_listing_fee_api(offer_ids, current_session_record, marketplace_id, conn.method) do
      data =
        case response do
          %OAuth2.Response{body: %{"feeSummaries" => fee_summaries}} ->
            total_fee =
              Enum.reduce(fee_summaries, [], fn x, acc ->
                [
                  %{
                    "marketplaceId" => x["marketplaceId"],
                    "totalFee" =>
                      Enum.reduce(
                        x["fees"],
                        0,
                        &(String.to_float(get_in(&1, ["amount", "value"])) + &2)
                      ),
                    "currency" => get_in(hd(x["fees"]), ["amount", "currency"])
                  }
                  | acc
                ]
              end)

            %{data: total_fee}

          msg ->
            msg
        end

      conn
      |> render("message.json",
        message: data
      )
    else
      {:error, %OAuth2.Response{body: body}} -> {:error, body}
      {:error, "Invalid SKUs"} = error -> error
      _ -> {:error, "Error while updating on SSG"}
    end
  end

  def validate_variant_skus(params) do
    parent = get_in(params, ["parent", "variantSKUs"]) |> Enum.sort()

    variation_products =
      Enum.map(get_in(params, ["variation_products"]), & &1["sku"]) |> Enum.sort()

    variation_offers = Enum.map(get_in(params, ["variation_offers"]), & &1["sku"]) |> Enum.sort()

    if(
      parent == variation_products && variation_products == variation_offers &&
        length(parent) == length(Enum.uniq(parent)),
      do: {:ok, params},
      else: {:error, "Invalid SKUs"}
    )
  end

  def publish(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"inventoryItemGroupKey" => parent_sku, "marketplaceId" => marketplace_id}
      ) do
    with {:ok, %OAuth2.Response{body: %{"listingId" => listing_id} = response}} <-
           publish_api(parent_sku, current_session_record, marketplace_id),
         {:ok, offer} <-
           Offers.update_offer_by_sku(
             parent_sku,
             %{"listing_id" => listing_id, "status" => "active"},
             current_session_record
           ),
         {:ok, _product} <-
           Products.update_product_by_sku(
             offer.sku,
             %{"status" => "active"},
             current_session_record
           ) do
      conn
      |> render("message.json", message: response)
    end
  end

  def show(%{assigns: %{current_session_record: csr}} = conn, %{"sku" => sku}) do
    case VariationProducts.get_product_by_sku(sku, csr) do
      nil ->
        {:error, :not_found}

      %{variation_offers: vo, variation_products: vp} = product ->
        product =
          if(product.variant_skus == nil) do
            %{product: product, offer: Offers.get_offer_by_sku(sku, csr)}
          else
            product = Map.drop(product, [:variation_offers, :variation_products])

            mvl =
              %{parent: product, variation_offers: vo, variation_products: vp}
              |> Listings.make_response_identical_to_input_json(csr)

            struct(%Mvl{}, mvl)
          end

        conn
        |> put_status(200)
        |> render("product.json", product: product)
    end
  end

  def delete(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"inventoryItemGroupKey" => sku, "marketplace_id" => marketplace_id}
      ) do
    with product when not is_nil(product) <-
           VariationProducts.get_product_by_sku(sku, current_session_record),
         {:ok, %OAuth2.Response{body: _body}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory_item", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.delete(
             (Utils.get_route("delete_inventory_group", "EBAY") <> "/#{sku}")
             |> URI.encode(&URI.char_unreserved?/1),
             [],
             [
               {"content-type", "application/json"},
               {"content-language", Utils.get_content_language(marketplace_id)}
             ]
           ),
         {:ok, _} <- VariationProducts.update_product_and_offer(sku, current_session_record) do
      conn
      |> render("message.json", message: "Deleted one item successfully")
    else
      nil -> {:error, "Product not found"}
      {:error, %OAuth2.Response{body: body}} -> {:error, body}
    end
  end

  def withdraw(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"inventoryItemGroupKey" => sku, "marketplace_id" => marketplace_id}
      ) do
    with product when not is_nil(product) <-
           VariationProducts.get_product_by_sku(sku, current_session_record),
         {:ok, %OAuth2.Response{body: _body}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory_item", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.post(
             Utils.get_route("withdraw_inventory_group", "EBAY"),
             %{"inventoryItemGroupKey" => sku, "marketplaceId" => marketplace_id},
             [
               {"content-type", "application/json"},
               {"content-language", Utils.get_content_language(marketplace_id)}
             ]
           ),
         {:ok, _} <- VariationProducts.update_product_and_offer(sku, current_session_record) do
      conn
      |> render("message.json", message: "OK")
    else
      nil -> {:error, "Product not found"}
      {:error, %OAuth2.Response{body: body}} -> {:error, body}
    end
  end

  defp get_description_template_for_parent(%{"variation_offers" => [offer | _]} = params, user_id) do
    offer =
      Map.drop(offer, ["pricingSummary", "availableQuantity"])
      |> Map.put("listingDescriptionTemplateId", params["parent"]["listingDescriptionTemplateId"])
      |> Map.put("marketplaceId", offer["marketplace_id"])

    Configurations.compute_description_template(
      user_id,
      offer,
      params["parent"]["sku"]
    )
  end

  defp ebay_bulk_create_or_update_inventory(product, vp, marketplace_id, csr) do
    Enum.chunk_every(vp, 25)
    |> Enum.reduce_while([], fn vp, _acc ->
      vp =
        Enum.map(vp, fn vp ->
          Data.form_params_for_bulk_create(product, vp, marketplace_id, csr)
          |> Data.stitch_inventory_item()
          |> Map.put("sku", vp.sku)
          |> Map.put(
            "locale",
            String.replace(Utils.get_content_language(marketplace_id), "-", "_")
          )
        end)

      vp = Map.put(%{}, "requests", vp)

      case OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("bulk_create_inventory", "EBAY"),
             csr
           )
           |> OAuth2.Client.post(
             Utils.get_route("bulk_create_inventory", "EBAY"),
             vp,
             [
               {"content-type", "application/json"},
               {"content-language", Utils.get_content_language(marketplace_id)}
             ]
           ) do
        {:ok, %OAuth2.Response{body: _body}} = response ->
          {:cont, response}

        {:error, _} = response ->
          {:halt, response}
      end
    end)
  end

  defp group_inventory_items(product, marketplace_id, params, csr) do
    description =
      if(params["parent"]["listingDescriptionTemplateId"]) do
        get_description_template_for_parent(params, csr.user_id)
      else
        params["parent"]["description"]
      end

    OauthEbay.session_to_client(
      "Bearer",
      Utils.get_host("inventory_item_group", "EBAY"),
      csr
    )
    |> OAuth2.Client.put(
      Utils.get_route("create_or_replace_inventory_item_group", "EBAY") <>
        "/#{product.sku |> URI.encode(&URI.char_unreserved?/1)}",
      Data.form_group_inventory_params(product) |> Map.put("description", description),
      [
        {"content-type", "application/json"},
        {"content-language", Utils.get_content_language(marketplace_id)}
      ]
    )
  end

  def ebay_create_offers(params, db_vo, product, marketplace_id, csr) do
    vo = params["variation_offers"]
    bulk_skus = VariationOffers.get_ebay_not_submitted(product.variant_skus, csr)
    update_skus = product.variant_skus -- bulk_skus

    vo =
      Enum.map(
        vo,
        fn x ->
          Map.drop(x, ["marketplace_id"])
          |> Map.put("marketplaceId", x["marketplace_id"])
          |> Map.put("listingDescription", get_description_template(x, params, csr))
        end
      )

    offers = Enum.group_by(vo, &(&1["sku"] in bulk_skus))
    offers_for_create = offers[true]
    offers_for_update = offers[false]

    with {:ok, created_offer_ids} <-
           create_bulk_offers(offers_for_create, db_vo, marketplace_id, csr),
         {:ok, updated_offer_ids} <-
           update_offers(offers_for_update, update_skus, marketplace_id, csr) do
      {:ok, created_offer_ids ++ updated_offer_ids}
    else
      {:error, body} ->
        {:error, body}

      _ ->
        {:error, "Unknown"}
    end
  end

  defp get_description_template(map, params, csr) do
    res =
      Configurations.compute_description_template(
        csr.user_id,
        map
        |> Map.put("listing_id", map["listingId"])
        |> Map.put(
          "listingDescriptionTemplateId",
          params["parent"]["listingDescriptionTemplateId"]
        ),
        params["parent"]["sku"]
      )

    if is_nil(res), do: params["parent"]["description"], else: res
  end

  defp create_bulk_offers(offers_for_create, _, _, _) when is_nil(offers_for_create),
    do: {:ok, []}

  defp create_bulk_offers(offers_for_create, db_vo, marketplace_id, csr) do
    Enum.chunk_every(offers_for_create, 25)
    |> Enum.reduce_while({:ok, []}, fn offers_for_create, acc ->
      case create_bulk_offers_api(
             offers_for_create,
             csr,
             marketplace_id
           ) do
        {:ok, %OAuth2.Response{body: body}} ->
          update_variation_offers(body, db_vo, acc)

        error ->
          {:halt, error}
      end
    end)
  end

  defp update_variation_offers(body, db_vo, acc) do
    offers =
      Enum.reduce(body["responses"], [], fn response, acc ->
        res = Enum.find(db_vo, &(&1[:sku] == response["sku"]))

        [
          Map.put(res, :offer_id, response["offerId"])
          |> Map.put(:is_submitted, true)
          |> Map.put(
            :updated_at,
            NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
          )
          | acc
        ]
      end)

    VariationOffers.update_offers(offers)
    {:cont, {:ok, Enum.map(body["responses"], & &1["offerId"]) ++ elem(acc, 1)}}
  end

  defp create_bulk_offers_api(offers_for_create, csr, marketplace_id) do
    OauthEbay.session_to_client(
      "Bearer",
      Utils.get_host("offer", "EBAY"),
      csr
    )
    |> OAuth2.Client.post(
      Utils.get_route("create_bulk_offers", "EBAY"),
      %{"requests" => offers_for_create},
      [
        {"content-type", "application/json"},
        {"content-language", Utils.get_content_language(marketplace_id)}
      ]
    )
  end

  defp update_offers(offers_for_update, _, _, _) when is_nil(offers_for_update), do: {:ok, []}

  defp update_offers(offers_for_update, update_skus, marketplace_id, csr) do
    offer_ids = SellSetGoApi.Offers.VariationOffers.get_offer_ids(update_skus, csr)

    offers_for_update =
      Enum.map(
        offers_for_update,
        &Map.put(
          &1,
          "offer_id",
          Enum.find(offer_ids, fn x -> x.sku == &1["sku"] end).offer_id
        )
      )

    Enum.reduce_while(offers_for_update, {:ok, []}, fn offer, acc ->
      case update_offer_api(offer, csr, marketplace_id) do
        {:ok, %OAuth2.Response{body: _body}} ->
          {:cont, {:ok, [offer["offer_id"] | elem(acc, 1)]}}

        {:error, %OAuth2.Response{body: _body}} = res ->
          {:halt, res}
      end
    end)
  end

  defp update_offer_api(offer, csr, marketplace_id) do
    OauthEbay.session_to_client(
      "Bearer",
      Utils.get_host("offer", "EBAY"),
      csr
    )
    |> OAuth2.Client.put(
      Utils.get_route("offer", "EBAY") <> "/#{offer["offer_id"]}",
      offer,
      [
        {"content-type", "application/json"},
        {"content-language", Utils.get_content_language(marketplace_id)}
      ]
    )
  end

  defp get_listing_fee_api(_, _, _, "PUT"), do: {:ok, "Product updated"}

  defp get_listing_fee_api(offer_ids, csr, marketplace_id, "POST") do
    OauthEbay.session_to_client(
      "Bearer",
      Utils.get_host("get_listing_fee", "EBAY"),
      csr
    )
    |> OAuth2.Client.post(
      Utils.get_route("get_listing_fee", "EBAY"),
      %{"offers" => Enum.map(offer_ids, &%{"offerId" => &1})},
      [
        {"content-type", "application/json"},
        {"content-language", Utils.get_content_language(marketplace_id)}
      ]
    )
  end

  defp publish_api(parent_sku, csr, marketplace_id) do
    OauthEbay.session_to_client(
      "Bearer",
      Utils.get_host("offer", "EBAY"),
      csr
    )
    |> OAuth2.Client.post(
      Utils.get_route("publish_mvl_offer", "EBAY"),
      %{"inventoryItemGroupKey" => parent_sku, "marketplaceId" => marketplace_id},
      [
        {"content-type", "application/json"},
        {"content-language", Utils.get_content_language(marketplace_id)}
      ]
    )
  end
end
