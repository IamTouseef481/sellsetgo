defmodule SellSetGoApi.Inventory.Products do
  @moduledoc """
  This module contains the API for the Sell Set Go Inventory Products API.
  """
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias SellSetGoApi.Inventory.{Data, Product, VariationProducts}
  alias SellSetGoApi.{Listings, OauthEbay, Repo, Reports, Utils}
  alias SellSetGoApi.Listings.Image
  alias SellSetGoApi.Offers.{Offer, Offers, VariationOffers}

  def create_product(params, csr) do
    product_params = parse_product_params(params)

    {:ok, product} =
      case get_product_by_sku(params["sku"], csr) do
        nil ->
          product =
            %Product{}
            |> Product.changeset(product_params |> Map.put("status", "draft"))
            |> Repo.insert!()

          images = Listings.get_images_from_ids(product.image_ids, product.user_id)
          {:ok, Map.put(product, :images, images)}

        product ->
          product_params = Map.delete(product_params, "sku")

          product
          |> Product.changeset(product_params)
          |> Repo.update()
      end

    from(i in Image, where: i.id in ^product.image_ids)
    |> Repo.update_all(set: [sku: product.sku])

    # update_images(params["image_order"], product.sku)

    {:ok, product}
  end

  def create_products(products) do
    if Product.changeset_valid_for_all?(%Product{}, products) do
      Repo.insert_all(Product, products,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

      {:ok, products}
    else
      {:error, "Invalid data"}
    end
  end

  def create_product_and_offer(params, csr) do
    Multi.new()
    |> Multi.run(:create_product, fn _repo, _cond ->
      create_product(params, csr)
    end)
    |> Multi.run(:create_offer, fn _repo, _cond ->
      Offers.create_offer(params, csr)
    end)
    |> Repo.transaction()
  end

  def get_product(id) do
    Repo.get!(Product, id)
  end

  def get_product(sku, user_id, listing_id) do
    sku = if is_number(sku), do: to_string(sku), else: sku

    from(p in Product)
    |> join(:left, [p], o in Offer, on: p.sku == o.sku and p.user_id == o.user_id)
    |> where([p, o], p.user_id == ^user_id and p.sku == ^sku and o.listing_id == ^listing_id)
    |> Repo.one()
  end

  def get_product_by_sku(sku, %{user_id: user_id}) do
    case Repo.get_by(Product, sku: sku, user_id: user_id) do
      nil ->
        nil

      product ->
        product =
          if product.variant_skus do
            %{
              variation_products: VariationProducts.get_variations_by_parent(sku, user_id),
              variation_offers: VariationOffers.get_variations_by_parent(sku, user_id)
            }
            |> Map.merge(product)
          else
            product
          end

        images = Listings.get_images_from_ids(product.image_ids, product.user_id)
        Map.put(product, :images, images)
    end
  end

  def get_product_compatibility(user_id, sku) do
    from(p in Product)
    |> where([p], p.user_id == ^user_id and p.sku == ^sku)
    |> select([p], %{vehicle_compatibility: p.vehicle_compatibility})
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      vehicle_compatibility ->
        {:ok, vehicle_compatibility}
    end
  end

  def update_product(%{id: id}, params) do
    get_product(id)
    |> Product.changeset(params)
    |> Repo.update()
  end

  def update_product_by_sku(sku, params, %{user_id: user_id}) do
    Repo.get_by(Product, sku: sku, user_id: user_id)
    |> Product.changeset(params)
    |> Repo.update()
  end

  def update_price_and_quantity(update_list, %{user_id: user_id}) do
    Enum.each(update_list, fn %{"sku" => sku} = params ->
      update_product_quantity(sku, params["shipToLocationAvailability"], user_id)
      update_offers(params["offers"])
    end)
  end

  def update_product_quantity(_sku, nil, _user_id), do: :ok

  def update_product_quantity(sku, quantity, user_id) do
    case Repo.get_by(Product, sku: sku, user_id: user_id)
         |> Product.changeset(quantity)
         |> Repo.update() do
      {:ok, _product} ->
        :ok

      _error ->
        raise "Something went wrong on updating quantity in Inventory with sku: #{sku}"
    end
  end

  defp update_offers(nil), do: :ok
  defp update_offers([]), do: :ok

  defp update_offers(offers_list) do
    Enum.each(offers_list, fn %{"offerId" => offer_id} = attrs ->
      case Repo.get_by(Offer, offer_id: offer_id) do
        nil ->
          raise "Offer with offer_id: #{offer_id} not found"

        offer ->
          update_offer_condition(offer, attrs["price"], attrs["availableQuantity"])
      end
    end)
  end

  defp update_offer_condition(offer, price, quantity) do
    cond do
      quantity == nil and price == nil ->
        :ok

      quantity == nil ->
        parse_and_update_offer(offer, "price", price)

      price == nil ->
        parse_and_update_offer(offer, "quantity", quantity)

      true ->
        parse_and_update_offer(offer, price, quantity)
    end
  end

  defp parse_product_params(%{
         "inventory" => %{"product" => product} = inventory,
         "user_id" => user_id,
         "sku" => sku
       }) do
    %{
      "aspects" => product["aspects"],
      "condition" => inventory["condition"],
      "description" => product["description"],
      "image_ids" => product["imageIds"],
      "package_weight_and_size" => inventory["packageWeightAndSize"],
      "quantity" => get_in(inventory, ["availability", "shipToLocationAvailability", "quantity"]),
      "sku" => sku,
      "title" => product["title"],
      "user_id" => user_id,
      "ean" => product["ean"],
      "isbn" => product["isbn"],
      "mpn" => product["mpn"],
      "upc" => product["upc"],
      "bc_fields" => product["bc_fields"],
      "variant_skus" => product["variantSKUs"],
      "aspects_image_varies_by" => product["variesBy"]["aspectsImageVariesBy"],
      "specifications" => product["variesBy"]["specifications"] || []
    }
  end

  def parse_and_update_offer(offer, "price", price) do
    offer.offer_detail
    |> Map.merge(%{
      "pricingSummary" => %{"price" => price}
    })
    |> update_offer_details(offer)
  end

  def parse_and_update_offer(offer, "quantity", quantity) do
    offer.offer_detail
    |> Map.merge(%{
      "availableQuantity" => quantity
    })
    |> update_offer_details(offer)
  end

  def parse_and_update_offer(offer, price, quantity) do
    offer.offer_detail
    |> Map.merge(%{
      "pricingSummary" => %{"price" => price},
      "availableQuantity" => quantity
    })
    |> update_offer_details(offer)
  end

  defp update_offer_details(offer_detail, offer) do
    case offer
         |> Offer.changeset(%{"offer_detail" => offer_detail})
         |> Repo.update() do
      {:ok, _offer} ->
        :ok

      _error ->
        raise "Something went wrong on updating offer_id: #{offer.offer_id}"
    end
  end

  def list_active_products_by_skus(user_id, skus, marketplace_id) do
    query =
      from(p in Product,
        where: p.user_id == ^user_id and p.status == "active",
        join: o in Offer,
        on: p.sku == o.sku and o.user_id == p.user_id,
        where: o.status == "active" and o.marketplace_id == ^marketplace_id,
        select: %{product: p, offer_id: o.offer_id}
      )

    case skus do
      [-1] ->
        query

      skus ->
        where(query, [p], p.sku in ^skus)
    end
    |> Repo.all()
  end

  def bulk_update_quantity(csr, %{
        "marketplace_id" => marketplace_id,
        "quantity" => quantity,
        "skus" => skus
      }) do
    products = list_active_products_by_skus(csr.user_id, skus, marketplace_id)
    chunk_list = Enum.chunk_every(products, 25)

    responses =
      Enum.map(chunk_list, fn list ->
        stitch_requests_for_ebay(list, quantity)
      end)
      |> Enum.map(fn req ->
        Task.async(fn ->
          update_quantity_in_ebay(req, csr, marketplace_id)
        end)
      end)

    success = get_processed_responses(responses)

    from(p in Product,
      where: p.user_id == ^csr.user_id and p.sku in ^success
    )
    |> Repo.update_all(set: [quantity: quantity])

    update_offer_quantity_by_sku_in_ssg(quantity, success, csr.user_id)

    failed = Enum.map(products, fn %{product: %{sku: sku}} -> sku end) -- success
    %{success: success, failed: failed}
  end

  def stitch_requests_for_ebay(item_list, quantity) do
    %{
      requests:
        Enum.map(item_list, fn %{product: %{sku: sku}, offer_id: offer_id} ->
          %{
            sku: sku,
            offers: [
              %{
                availableQuantity: quantity,
                offerId: offer_id
              }
            ],
            shipToLocationAvailability: %{
              quantity: quantity
            }
          }
        end)
    }
  end

  defp get_processed_responses(responses) do
    Enum.reduce(responses, [], fn resp, acc ->
      {_, %{body: body}} = Task.await(resp)

      Map.get(body, "responses", []) ++ acc
    end)
    |> Enum.reduce([], fn
      %{"statusCode" => 200, "sku" => sku}, acc -> acc ++ [sku]
      _, acc -> acc
    end)
    |> Enum.uniq()
  end

  defp update_quantity_in_ebay(request, csr, marketplace_id) do
    OauthEbay.session_to_client(
      "Bearer",
      Utils.get_host("inventory_item", "EBAY"),
      csr
    )
    |> OAuth2.Client.post(
      Utils.get_route("bulk_update_price_quantity", "EBAY"),
      request,
      [
        {"content-type", "application/json"},
        {"content-language", Utils.get_content_language(marketplace_id)}
      ],
      recv_timeout: 30_000
    )
  end

  def update_offer_quantity_by_sku_in_ssg(quantity, sku, user_id) do
    from(o in Offer,
      where: o.user_id == ^user_id and o.sku in ^sku
    )
    |> Repo.all()
    |> Enum.each(fn offer ->
      offer_detail =
        offer.offer_detail
        |> Map.put("availableQuantity", quantity)

      {:ok, _update_offer} =
        offer |> Offer.changeset(%{"offer_detail" => offer_detail}) |> Repo.update()
    end)
  end

  def get_new_arrivals(user_id, marketplace_id) do
    Product
    |> where([p], p.user_id == ^user_id and p.status == "active")
    |> join(:inner, [p], o in Offer, on: p.sku == o.sku and p.user_id == o.user_id)
    |> where([p, o], o.status == "active" and o.marketplace_id == ^marketplace_id)
    |> select([p, o], %{
      price: o.offer_detail["pricingSummary"]["price"]["value"],
      title: p.title,
      listing_id: o.listing_id,
      image_ids: p.image_ids,
      inserted_at: p.inserted_at
    })
    |> order_by(desc: :inserted_at)
    |> limit(10)
    |> Repo.all()
  end

  def process_update_csv(%{user_id: user_id} = csr, csv, marketplace_id) do
    items_in_csv = Listings.read_csv(csv)

    %{items_in_db: items_in_db, items_not_in_db: items_not_in_db, products: products, skus: skus} =
      Listings.split_items_in_db(items_in_csv, user_id)

    currency = Utils.get_currency(marketplace_id)
    lang = Utils.get_content_language(marketplace_id)

    offers =
      from(o in Offer, where: o.user_id == ^user_id and o.sku in ^skus)
      |> Repo.all()

    %{products: products, offers: offers} =
      Data.stitch_product_offer_for_bulk_update_in_ebay(
        items_in_db,
        currency,
        lang,
        products,
        offers
      )
      |> Enum.reduce(%{products: [], offers: []}, fn item, acc ->
        %{
          products: acc.products ++ [item["product"]],
          offers: acc.offers ++ [item["offer"]]
        }
      end)

    update_products_sku = bulk_update_products_in_ebay(products, csr, lang, items_in_db)
    update_offers_id = bulk_update_offers_in_ebay(offers, csr, items_in_db, lang)
    bulk_update_offers_in_db(offers, user_id)
    bulk_update_products_in_db(products)

    total =
      items_not_in_db ++ update_offers_id.failed ++ update_products_sku.failed ++ items_in_db

    export_bulk_update_csv(total, user_id)
  end

  defp bulk_update_products_in_ebay(products, csr, lang, items_in_db) do
    Enum.chunk_every(products, 25)
    |> Enum.map(fn chunk ->
      {_, %OAuth2.Response{body: body}} =
        OauthEbay.session_to_client(
          "Bearer",
          Utils.get_host("inventory_item", "EBAY"),
          csr
        )
        |> OAuth2.Client.post(
          "/sell/inventory/v1/bulk_create_or_replace_inventory_item",
          %{requests: chunk},
          [
            {"content-type", "application/json"},
            {"content-language", lang}
          ],
          recv_timeout: 30_000
        )

      with nil <- body["responses"] do
        error = List.first(body["error"])
        error_parameter = List.first(error["parameters"])
        "#{error["message"]}. #{error_parameter["value"]}"
      end
    end)
    |> List.flatten()
    |> Enum.reduce(%{success: [], failed: []}, fn
      %{"statusCode" => 200, "sku" => sku}, acc ->
        Map.put(acc, :success, acc.success ++ [sku])

      %{"sku" => sku}, acc ->
        item =
          Enum.find(items_in_db, fn item -> item.sku == sku end)
          |> Map.put("error", "Error updating inventory in EBay")

        Map.put(acc, :failed, acc.failed ++ [item])

      error_message, _acc ->
        raise error_message
    end)
  end

  defp bulk_update_offers_in_ebay(offers, csr, items_in_db, lang) do
    Enum.reduce(offers, %{success: [], failed: []}, fn %{"offer_id" => offer_id} = offer, acc ->
      OauthEbay.session_to_client(
        "Bearer",
        Utils.get_host("offer", "EBAY"),
        csr
      )
      |> OAuth2.Client.put_header("content-type", "application/json")
      |> OAuth2.Client.put_header(
        "content-language",
        lang
      )
      |> OAuth2.Client.put(
        Utils.get_route("offer", "EBAY") <> "/#{offer_id}",
        offer,
        recv_timeout: 30_000
      )
      |> case do
        {:ok, _} ->
          %{success: acc.success ++ [offer_id], failed: acc.failed}

        _ ->
          %{
            success: acc.success,
            failed: acc.failed ++ [add_error_to_offer(items_in_db, offer_id)]
          }
      end
    end)
  end

  defp bulk_update_offers_in_db(offers, user_id) do
    Enum.map(offers, fn %{"offer_id" => offer_id} = offer ->
      %{
        offer_detail:
          offer
          |> Map.put("listingDescription", offer["description"])
          |> Map.delete("offer_id")
          |> Map.delete("description"),
        offer_id: offer_id,
        user_id: user_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
    # This is to avoid PSQL updating parameter error
    |> Enum.chunk_every(1000)
    |> Enum.each(fn offers_to_update ->
      Repo.insert_all(Offer, offers_to_update,
        conflict_target: [:offer_id, :user_id],
        on_conflict: {:replace, [:offer_detail]}
      )
    end)
  end

  defp bulk_update_products_in_db(products) do
    Enum.map(products, fn %{"sku" => sku} = product ->
      %{
        condition: product["condition"],
        quantity:
          get_in(product, [
            "availability",
            "shipToLocationAvailability",
            "quantity"
          ])
          |> Utils.convert_to_float_or_integer(),
        package_weight_and_size: get_in(product, ["packageWeightAndSize"]),
        sku: sku,
        title: product["title"],
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
      |> Utils.insert_field_if_exist(:ean, product["ean"])
      |> Utils.insert_field_if_exist(:isbn, product["isbn"])
      |> Utils.insert_field_if_exist(:mpn, product["mpn"])
      |> Utils.insert_field_if_exist(:upc, product["upc"])
    end)

    # This is to avoid PSQL updating parameter error
    |> Enum.chunk_every(1000)
    |> Enum.each(fn products_to_update ->
      Repo.insert_all(Product, products_to_update,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace, [:condition, :quantity, :package_weight_and_size, :title]}
      )
    end)
  end

  defp add_error_to_offer(items_in_db, offer_id) do
    Enum.find(items_in_db, fn item -> item["offer_id"] == offer_id end)
    |> Map.put("error", "Error updating offer in EBay")
  end

  defp export_bulk_update_csv(total, user_id) do
    Enum.group_by(total, fn item -> item["sku"] end)
    |> Enum.reduce([], fn {_sku, items}, acc ->
      acc ++ [merging_errors(items)]
    end)
    |> Reports.export_product_offer_reports("bulk_update", user_id)
  end

  defp merging_errors(items) do
    Enum.reduce(items, %{}, fn item, acc1 ->
      acc_error = Map.get(acc1, "error", "")
      item_error = Map.get(item, "error", "")

      cond do
        acc_error == "" and item_error == "" ->
          Map.put(item, "error", "")

        acc_error != "" and item_error == "" ->
          Map.put(item, "error", "#{acc_error}")

        acc_error == "" and item_error != "" ->
          Map.put(item, "error", "#{item_error}")

        true ->
          Map.put(item, "error", "#{acc_error}, #{item_error}")
      end
    end)
  end

  # defp update_images(images, sku) do
  #   Enum.each(images, fn {order, image_id} ->
  #     Listings.get_image!(image_id)
  #     |> Image.changeset(%{order: order, sku: sku})
  #     |> Repo.update()
  #   end)
  # end

  def update_product_image_order(params) do
    Repo.insert_all(Image, params, conflict_target: [:id], on_conflict: {:replace, [:order]})
  end

  def get_used_skus(skus, %{user_id: user_id}) do
    from(p in Product)
    |> where([p], p.user_id == ^user_id and p.sku in ^skus)
    |> select([p], p.sku)
    |> Repo.all()
  end

  def get_related_items(user_id, marketplace_id, store_category_name) do
    Product
    |> where([p], p.user_id == ^user_id and p.status == "active")
    |> join(:inner, [p], o in Offer, on: p.sku == o.sku and p.user_id == o.user_id)
    |> where(
      [p, o],
      o.status == "active" and o.marketplace_id == ^marketplace_id and
        fragment("? @> ?", o.offer_detail["storeCategoryNames"], ^store_category_name)
    )
    |> select([p, o], %{
      price: o.offer_detail["pricingSummary"]["price"]["value"],
      title: p.title,
      listing_id: o.listing_id,
      image_ids: p.image_ids,
      inserted_at: p.inserted_at
    })
    |> order_by(desc: :inserted_at)
    |> limit(10)
    |> Repo.all()
  end
end
