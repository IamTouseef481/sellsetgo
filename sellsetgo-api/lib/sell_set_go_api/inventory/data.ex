defmodule SellSetGoApi.Inventory.Data do
  @moduledoc """
  This module is used to stitch the data according to the ebay abi to create inventory item.
  """

  alias SellSetGoApi.{Configurations, Listings, Utils}

  @condition_enum ~w(NEW LIKE_NEW NEW_WITH_DEFECTS MANUFACTURER_REFURBISHED CERTIFIED_REFURBISHED
    EXCELLENT_REFURBISHED USED_EXCELLENT FOR_PARTS_OR_NOT_WORKING NEW_OTHER)

  def get_condition_enum() do
    @condition_enum
  end

  def stitch_inventory_item(
        %{
          "inventory" => %{"product" => product} = inventory,
          "user_id" => user_id
        } = _params
      ) do
    image_urls = Listings.get_provider_image_urls_from_ids(product["imageIds"], user_id)

    aspects =
      if Map.has_key?(product, "aspects") && is_map(elem(Enum.random(product["aspects"]), 1)) do
        Enum.reduce(product["aspects"], %{}, fn {_key, val}, acc -> Map.merge(acc, val) end)
      else
        product["aspects"]
      end

    {_val, inventory} =
      Map.get_and_update!(inventory, "product", fn val ->
        {val,
         Map.put(product, "imageUrls", image_urls)
         |> Map.put("aspects", aspects)
         |> Map.delete("imageIds")}
      end)

    inventory
  end

  def stitch_product_offer_for_bulk_update_in_ebay(items, currency, lang, products, offers) do
    items
    |> Enum.map(fn item ->
      product_in_db = Enum.find(products, fn product -> Map.get(product, :sku) == item["sku"] end)

      offer_in_db = Enum.find(offers, fn offer -> Map.get(offer, :sku) == item["sku"] end)

      offer_in_db =
        offer_in_db
        |> Map.get(:offer_detail)
        |> Map.put("offer_id", offer_in_db.offer_id)

      product = stitch_product_for_ebay(item, product_in_db, lang)

      offer = stitch_offer_params_for_ebay(item, offer_in_db, currency, product_in_db.user_id)

      %{
        "product" => product,
        "offer" => offer
      }
    end)
  end

  defp stitch_product_for_ebay(item, product_in_db, lang) do
    product_map =
      %{
        "title" => item["title"]
      }
      |> put_value_in_map_if_key_exists(item, product_in_db, "ean")
      |> put_value_in_map_if_key_exists(item, product_in_db, "isbn")
      |> put_value_in_map_if_key_exists(item, product_in_db, "mpn")
      |> put_value_in_map_if_key_exists(item, product_in_db, "upc")
      |> add_aspects(item, product_in_db)
      |> add_image_urls(item, product_in_db)

    %{
      "sku" => item["sku"],
      "locale" => String.replace(lang, "-", "_"),
      "product" => product_map,
      "availability" => %{
        "shipToLocationAvailability" => %{
          "quantity" => item["quantity"]
        }
      }
    }
    |> add_package_weight_and_size(item, product_in_db)
    |> put_value_in_map_if_key_exists(item, product_in_db, "condition")
  end

  defp stitch_offer_params_for_ebay(item, offer_in_db, currency, user_id) do
    store_category_names =
      if item["storeCategoryNames"] == nil,
        do: offer_in_db["storeCategoryNames"],
        else: [item["storeCategoryNames"]]

    offer = %{
      "availableQuantity" =>
        (item["quantity"] || offer_in_db["availableQuantity"])
        |> Utils.convert_to_float_or_integer(),
      "categoryId" => offer_in_db["categoryId"],
      "format" => offer_in_db["format"],
      "listingPolicies" => %{
        "fulfillmentPolicyId" =>
          item["fulfillmentPolicyId"] ||
            get_in(offer_in_db, ["listingPolicies", "fulfillmentPolicyId"]),
        "paymentPolicyId" =>
          item["paymentPolicyId"] ||
            get_in(offer_in_db, ["listingPolicies", "paymentPolicyId"]),
        "returnPolicyId" =>
          item["returnPolicyId"] ||
            get_in(offer_in_db, ["listingPolicies", "returnPolicyId"])
      },
      "pricingSummary" => %{
        "price" => %{
          "value" =>
            (item["price"] || get_in(offer_in_db, ["pricingSummary", "price", "value"]))
            |> Utils.convert_to_float_or_integer(),
          "currency" => currency
        }
      },
      "merchantLocationKey" => item["merchantLocationKey"] || offer_in_db["merchantLocationKey"],
      "storeCategoryNames" => store_category_names,
      "offer_id" => offer_in_db["offer_id"],
      "description" => item["listingDescription"] || offer_in_db["listingDescription"],
      "listingDescriptionTemplateId" => offer_in_db["listingDescriptionTemplateId"],
      "marketplaceId" => offer_in_db["marketplaceId"],
      "listingDuration" => offer_in_db["listingDuration"],
      "ebayCategoryNames" => offer_in_db["ebayCategoryNames"]
    }

    Configurations.compute_description_template(
      user_id,
      Map.merge(offer_in_db, offer),
      item["sku"]
    )
    |> then(fn desc ->
      Map.put(offer, "listingDescription", desc)
    end)
  end

  def put_value_in_map_if_key_exists(map, item, "packageWeight") do
    value = item["packageWeight"]

    if Utils.is_empty?(value) do
      map
    else
      Map.put(map, "weight", %{"value" => value, "unit" => "KILOGRAM"})
    end
  end

  def put_value_in_map_if_key_exists(map, item, item_in_db, key) do
    value = if item[key] == nil, do: item_in_db[:"#{key}"], else: item[key]
    value = if is_bitstring(value), do: String.trim(value), else: value

    if Utils.is_empty?(value) do
      map
    else
      Map.put(map, key, value)
    end
  end

  def add_package_weight_and_size(map, item, product_in_db) do
    item_package_type = item["packageType"] |> String.trim()
    item_package_weight = item["packageWeight"] |> String.trim()

    cond do
      Utils.is_empty?(item_package_weight) and Utils.is_empty?(item_package_type) ->
        Map.put(map, "packageWeightAndSize", Map.get(product_in_db, :package_weight_and_size))

      Utils.is_empty?(item_package_weight) ->
        Map.put(map, "packageWeightAndSize", %{
          "weight" => Map.get(product_in_db, :package_weight_and_size) |> Map.get("weight"),
          "packageType" => item_package_type
        })

      Utils.is_empty?(item_package_type) ->
        Map.put(map, "packageWeightAndSize", %{
          "weight" => %{"unit" => "KILOGRAM", "value" => item_package_weight},
          "packageType" =>
            Map.get(product_in_db, :package_weight_and_size) |> Map.get("packageType")
        })

      true ->
        Map.put(map, "packageWeightAndSize", %{
          "weight" => %{"unit" => "KILOGRAM", "value" => item_package_weight},
          "packageType" => item_package_type
        })
    end
  end

  defp add_aspects(map, _item, product_in_db) do
    case Map.get(product_in_db, :aspects) do
      %{"dynamic" => dynamic, "custom" => custom} ->
        Map.put(map, "aspects", Map.merge(dynamic, custom))

      %{"dynamic" => dynamic} ->
        Map.put(map, "aspects", dynamic)

      %{"custom" => custom} ->
        Map.put(map, "aspects", custom)

      aspects ->
        Map.put(map, "aspects", aspects)
    end
  end

  defp add_image_urls(map, _item, product_in_db) do
    Map.get(product_in_db, :image_ids)
    |> Listings.get_provider_image_urls_from_ids(product_in_db.user_id)
    |> then(fn image_urls -> Map.put(map, "imageUrls", image_urls) end)
  end

  def form_group_inventory_params(product) do
    %{
      "aspects" =>
        if(Enum.all?(product.aspects, &is_map(elem(&1, 1))),
          do: Enum.reduce(product.aspects, %{}, fn {_key, val}, acc -> Map.merge(acc, val) end),
          else: nil
        ),
      "description" => product.description,
      "imageUrls" =>
        Listings.get_provider_image_urls_from_ids(product.image_ids, product.user_id),
      "inventoryItemGroupKey" => product.sku,
      "title" => product.title,
      "variantSKUs" => product.variant_skus,
      "variesBy" => %{
        "aspectsImageVariesBy" => product.aspects_image_varies_by,
        "specifications" => product.specifications
      }
    }
  end

  def form_params_for_bulk_create(product, variation_product, marketplace_id, %{user_id: user_id}) do
    %{
      "inventory" => %{
        "product" => %{
          "title" => product.title,
          "imageIds" => variation_product.image_ids,
          "aspects" => variation_product.aspects
        },
        "description" => product.description,
        "condition" => variation_product.condition,
        "packageWeightAndSize" => variation_product.package_weight_and_size,
        "availability" => %{
          "shipToLocationAvailability" => %{
            "quantity" => 10
          }
        }
      },
      "sku" => variation_product.sku,
      "marketplaceId" => marketplace_id,
      "user_id" => user_id
    }
  end
end
