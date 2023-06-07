defmodule SellSetGoApi.Offers.Offers do
  @moduledoc """
  The Offers context.
  """

  alias SellSetGoApi.Offers.Offer
  alias SellSetGoApi.Inventory.{Product, Data}
  alias SellSetGoApi.Repo
  alias SellSetGoApi.{Configurations, OauthEbay, Utils}
  import Ecto.Query, warn: false

  def create_offer(params, csr) do
    case get_offer_by_sku(params["sku"], csr) do
      nil ->
        %Offer{}
        |> Offer.changeset(form_offer_params(params))
        |> Repo.insert()

      offer ->
        offer_params = form_update_offer_params(params, offer)
        # may_be_update_category_in_ebay(offer_params, offer, csr)

        offer
        |> Offer.changeset(offer_params)
        |> Repo.update()
    end
  end

  def create_offers(offers) do
    if Offer.changeset_valid_for_all?(%Offer{}, offers) do
      Repo.insert_all(Offer, offers,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at, :is_submitted, :offer_id]}
      )

      {:ok, offers}
    else
      {:error, "Invalid data"}
    end
  end

  def get_offer_by_sku(sku, %{user_id: user_id}) do
    Repo.get_by(Offer, sku: sku, user_id: user_id)
  end

  def get_offer_listing_id_by_sku(sku, %{user_id: user_id}) do
    from(
      o in Offer,
      where: o.sku == ^sku and o.user_id == ^user_id,
      select: %{
        listing_id: o.listing_id,
        template_id: fragment("offer_detail->'listingDescriptionTemplateId'")
      },
      limit: 1
    )
    |> Repo.one()
  end

  def get_offer(id) do
    Repo.get!(Offer, id)
  end

  def update_offer(%{id: id}, params) do
    get_offer(id)
    |> Offer.changeset(params)
    |> Repo.update()
  end

  def update_offer_by_sku(sku, params, csr) do
    case get_offer_by_sku(sku, csr) do
      nil ->
        {:error, "No offer was found for this SKU"}

      offer ->
        offer
        |> Offer.changeset(params)
        |> Repo.update()
    end
  end

  def update_by_offer_id(offer_id, params) do
    offer =
      case Repo.get_by(Offer, offer_id: offer_id) do
        nil ->
          raise "Offer not found"

        offer ->
          offer
      end

    offer_params = form_update_offer_params(params, offer)

    offer
    |> Offer.changeset(offer_params)
    |> Repo.update()
  end

  def list_active_offers_by_skus(user_id, skus, marketplace_id) do
    query =
      from(o in Offer,
        left_join: p in Product,
        on: o.sku == p.sku and o.user_id == p.user_id,
        where:
          o.user_id == ^user_id and o.status == "active" and o.marketplace_id == ^marketplace_id,
        select: %{offer: o, product: p}
      )

    case skus do
      [-1] ->
        query

      skus ->
        where(query, [o], o.sku in ^skus)
    end
    |> Repo.all()
  end

  def bulk_update_description_template(csr, %{
        "marketplace_id" => marketplace_id,
        "description_template_id" => description_template_id,
        "skus" => skus
      }) do
    products = list_active_offers_by_skus(csr.user_id, skus, marketplace_id)

    responses =
      Enum.map(products, fn product ->
        offer = product.offer

        try do
          offer_detail =
            offer.offer_detail
            |> Map.put("listing_id", offer.listing_id)
            |> Map.put("listingDescriptionTemplateId", description_template_id)

          listing_description =
            Configurations.compute_description_template(
              csr.user_id,
              offer_detail,
              offer.sku
            )

          Task.async(fn ->
            with {:ok, %{body: _body}} <-
                   update_description_template_api(
                     product,
                     marketplace_id,
                     listing_description,
                     csr
                   ),
                 {:ok, _offer} <- update_description_template_id(offer, description_template_id) do
              {:ok, offer.sku}
            else
              {:error, %{body: %{"errors" => error}}} ->
                {:error, offer.sku, error}
            end
          end)
        rescue
          _ -> Task.async(fn -> {:error, offer.sku, "Unknown Error"} end)
        end
      end)

    Enum.reduce(responses, %{success: [], failed: []}, fn resp, acc ->
      case Task.await(resp) do
        {:ok, sku} ->
          Map.put(acc, :success, acc.success ++ [sku])

        {:error, sku, error} ->
          Map.put(acc, :failed, acc.failed ++ [%{sku: sku, error: error}])
      end
    end)
  end

  def update_description_template_api(products, marketplace_id, listing_description, csr) do
    offer = products.offer
    product = products.product
    offer_detail = offer.offer_detail

    if product.variant_skus do
      OauthEbay.session_to_client(
        "Bearer",
        Utils.get_host("inventory_item_group", "EBAY"),
        csr
      )
      |> OAuth2.Client.put(
        Utils.get_route("create_or_replace_inventory_item_group", "EBAY") <>
          "/#{product.sku |> URI.encode(&URI.char_unreserved?/1)}",
        Data.form_group_inventory_params(product) |> Map.put("description", listing_description),
        [
          {"content-type", "application/json"},
          {"content-language", Utils.get_content_language(marketplace_id)}
        ]
      )
    else
      OauthEbay.session_to_client(
        "Bearer",
        Utils.get_host("offer", "EBAY"),
        csr
      )
      |> OAuth2.Client.put_header("content-type", "application/json")
      |> OAuth2.Client.put_header(
        "content-language",
        Utils.get_content_language(marketplace_id)
      )
      |> OAuth2.Client.put(
        Utils.get_route("offer", "EBAY") <> "/#{offer.offer_id}",
        Map.put(offer_detail, "listingDescription", listing_description)
      )
    end
  end

  defp update_description_template_id(offer, description_template_id) do
    offer_detail =
      offer.offer_detail
      |> Map.put("listingDescriptionTemplateId", description_template_id)

    offer
    |> Offer.changeset(%{offer_detail: offer_detail})
    |> Repo.update()
  end

  defp form_offer_params(%{
         "offer" => offer,
         "user_id" => user_id,
         "sku" => sku,
         "marketplaceId" => marketplace_id
       }) do
    %{
      "offer_detail" => offer,
      "user_id" => user_id,
      "sku" => sku,
      "marketplace_id" => marketplace_id,
      "status" => "draft"
    }
  end

  # Executed when publishing the offer
  defp form_update_offer_params(%{"listing_id" => _listing_id} = params, _offer),
    do: params

  # Executed when withdrawing the offer
  defp form_update_offer_params(%{"status" => _status} = params, _offer),
    do: params

  # Executed when updating the offer
  defp form_update_offer_params(%{"offer" => offer} = params, existing_offer) do
    offer = Map.merge(existing_offer.offer_detail, offer)

    %{
      "offer_detail" => offer,
      "marketplace_id" => offer["marketplaceId"] || params["marketplaceId"]
    }
  end

  def may_be_update_category_in_ebay(
        %{"offer" => %{"category_id" => new_category_id}} = params,
        %{offer_detail: %{"category_id" => old_category_id}, offer_id: offer_id},
        csr
      ) do
    with true <- new_category_id != old_category_id,
         {:ok, offer} <-
           update_by_offer_id(offer_id, params),
         {:ok, %OAuth2.Response{body: _body}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("offer", "EBAY"),
             csr
           )
           |> OAuth2.Client.put_header("content-type", "application/json")
           |> OAuth2.Client.put_header(
             "content-language",
             Utils.get_content_language(offer.marketplace_id)
           )
           |> OAuth2.Client.put(
             Utils.get_route("offer", "EBAY") <> "/#{offer_id}",
             offer.offer_detail
             |> Map.put(
               "listingDescription",
               Configurations.compute_description_template(
                 csr.user_id,
                 offer.offer_detail |> Map.put("listing_id", offer.listing_id),
                 offer.sku
               )
             )
           ) do
      :ok
    else
      _ -> :ok
    end
  end

  def may_be_update_category_in_ebay(_offer_params, _offer, _csr), do: :ok
end
