defmodule SellSetGoApi.Inventory.VariationProducts do
  @moduledoc """
  This module contains the API for the Sell Set Go Inventory Products API.
  """
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias SellSetGoApi.Inventory.{VariationProduct, Products, Product}
  alias SellSetGoApi.{Listings, Repo}
  alias SellSetGoApi.Listings.Image
  alias SellSetGoApi.Offers.{VariationOffers, VariationOffer, Offers, Offer}

  def create_product(variation_products, user_id, parent) do
    product_params =
      Enum.map(
        variation_products,
        &(parse_product_params(&1, user_id, parent) |> Map.put(:status, "draft"))
      )

    if VariationProduct.changeset_valid_for_all?(%VariationProduct{}, product_params) do
      Repo.insert_all(VariationProduct, product_params,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

      {:ok, product_params}
    else
      {:error, "Invalid data"}
    end
  end

  def update_product(%{id: id}, params) do
    get_product(id)
    |> VariationProduct.changeset(params)
    |> Repo.update()
  end

  def create_products(variation_products) do
    if VariationProduct.changeset_valid_for_all?(%VariationProduct{}, variation_products) do
      Repo.insert_all(VariationProduct, variation_products,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

      {:ok, variation_products}
    else
      {:error, "Invalid data"}
    end
  end

  def create_product_and_offer(params, csr) do
    Multi.new()
    |> Multi.run(:create_product, fn _repo, _cond ->
      parent = %{
        "inventory" => %{"product" => params["parent"]},
        "user_id" => params["user_id"],
        "sku" => params["parent"]["sku"]
      }

      Products.create_product(parent, csr)
    end)
    |> Multi.run(:create_offer, fn _repo, _cond ->
      form_offer_params_from_product(
        params["parent"],
        params["user_id"],
        hd(params["variation_offers"])
      )
      |> Offers.create_offer(csr)
    end)
    |> Multi.run(:create_variation_products, fn _repo, _cond ->
      create_product(params["variation_products"], params["user_id"], params["parent"])
    end)
    |> Multi.run(:create_variation_offers, fn _repo, _cond ->
      VariationOffers.create_offers(
        params["variation_offers"],
        params["user_id"],
        params["parent"]["sku"]
      )
    end)
    |> Repo.transaction()
  end

  def update_product_and_offer(sku, %{user_id: user_id}) do
    Multi.new()
    |> Multi.run(:update_product, fn _repo, _cond ->
      {:ok, Products.update_product_by_sku(sku, %{"status" => "ended"}, %{user_id: user_id})}
    end)
    |> Multi.run(:update_variation_products, fn _repo, _cond ->
      update_products(sku, user_id)
    end)
    |> Multi.run(:update_variation_offers, fn _repo, _cond ->
      update_offers(sku, user_id)
    end)
    |> Repo.transaction()
  end

  def update_products(sku, user_id) do
    {:ok,
     from(vp in VariationProduct,
       where: vp.parent_sku == ^sku and vp.user_id == ^user_id,
       update: [set: [status: "ended"]]
     )
     |> Repo.update_all([])}
  end

  def submit_products(sku, %{user_id: user_id}) do
    from(vp in VariationProduct,
      where: vp.sku in ^sku and vp.user_id == ^user_id,
      update: [set: [is_submitted: true]]
    )
    |> Repo.update_all([])
  end

  def update_offers(sku, user_id) do
    {:ok,
     from(vo in VariationOffer,
       where: vo.parent_sku == ^sku and vo.user_id == ^user_id,
       update: [set: [status: "ended"]]
     )
     |> Repo.update_all([])}
  end

  def get_product(id) do
    Repo.get!(VariationProduct, id)
  end

  def get_product(sku, user_id, listing_id) do
    from(vp in VariationProduct)
    |> join(:left, [p], o in Offer, on: p.parent_sku == o.sku and p.user_id == o.user_id)
    |> where([vp, o], vp.user_id == ^user_id and vp.sku == ^sku and o.listing_id == ^listing_id)
    |> Repo.one()
  end

  def get_product_by_sku(parent_sku, %{user_id: user_id}) do
    case Repo.get_by(Product, sku: parent_sku, user_id: user_id) do
      nil ->
        nil

      product ->
        %{
          images: Listings.get_images_from_ids(product.image_ids, product.user_id),
          variation_products: get_variations_by_parent(parent_sku, user_id),
          variation_offers: VariationOffers.get_variations_by_parent(parent_sku, user_id)
        }
        |> Map.merge(product)
    end
  end

  #  def get_product_by_sku(sku, %{user_id: user_id}) do
  #    case Repo.get_by(Product, sku: sku, user_id: user_id)
  #         |> Repo.preload([:variation_products, :variation_offers]) do
  #      nil ->
  #        nil
  #
  #      product ->
  #        images = Listings.get_images_from_ids(product.image_ids, product.user_id)
  #        Map.put(product, :images, images)
  #    end
  #  end

  def get_variations_by_parent(parent_sku, user_id) do
    VariationProduct
    |> where([vp], vp.parent_sku == ^parent_sku and vp.user_id == ^user_id)
    |> Repo.all()
  end

  defp parse_product_params(%{"sku" => sku} = product, user_id, parent) do
    %{
      aspects: product["aspects"],
      condition: product["condition"],
      description: product["description"],
      image_ids:
        if(product["imageIds"] in [nil, []], do: parent["imageIds"], else: product["imageIds"]),
      package_weight_and_size: product["packageWeightAndSize"],
      quantity: get_in(product, ["availability", "shipToLocationAvailability", "quantity"]),
      sku: sku,
      title: product["title"],
      user_id: user_id,
      is_submitted: false,
      ean: product["ean"],
      isbn: product["isbn"],
      mpn: product["mpn"],
      upc: product["upc"],
      bc_fields: product["bc_fields"],
      parent_sku: parent["sku"],
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }
  end

  def update_product_image_order(params) do
    Repo.insert_all(Image, params, conflict_target: [:id], on_conflict: {:replace, [:order]})
  end

  defp form_offer_params_from_product(product, user_id, offer) do
    %{
      "user_id" => user_id,
      "sku" => product["sku"],
      "marketplaceId" => offer["marketplace_id"],
      "offer" => %{
        "storeCategoryNames" => offer["storeCategoryNames"],
        "marketplaceId" => offer["marketplace_id"],
        "format" => offer["format"],
        "listingDescription" => product["description"],
        "listingDescriptionTemplateId" => product["listingDescriptionTemplateId"],
        "listingDuration" => offer["listingDuration"],
        "listingPolicies" => offer["listingPolicies"],
        "categoryId" => offer["categoryId"],
        "merchantLocationKey" => offer["merchantLocationKey"]
      }
    }
  end

  def get_used_skus(skus, %{user_id: user_id}) do
    from(vp in VariationProduct)
    |> where([vp], vp.user_id == ^user_id and vp.sku in ^skus)
    |> select([vp], vp.sku)
    |> Repo.all()
  end
end
