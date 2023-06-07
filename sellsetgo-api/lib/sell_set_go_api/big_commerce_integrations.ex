defmodule SellSetGoApi.BigCommerceIntegrations do
  @moduledoc """
  BigCommerce Integrations context
  """
  import Ecto.Query

  alias SellSetGoApi.BigCommerceAPI
  alias SellSetGoApi.Integrations.BigCommerce
  alias SellSetGoApi.Integrations.BigCommerceSession
  alias SellSetGoApi.Repo
  alias SellSetGoApi.Offers.Offer
  alias SellSetGoApi.Offers.Offers
  alias SellSetGoApi.Inventory.Product
  alias SellSetGoApi.Repo

  @spec create(params :: any()) :: {:ok, String.t()} | {:error, any()}
  def create(%{"user_id" => user_id} = params) do
    with {:ok, true} <- is_big_commerce_enabled?(user_id),
         {:ok, true} <- {:ok, has_big_commerce_fields?(params)},
         {:ok, product_id} <- BigCommerceAPI.create(params),
         {:ok, :success} <- update_big_commerce_product_id(params, product_id) do
      {:ok, "Successfully submitted the product to BigCommerce."}
    else
      {:ok, false} ->
        {:ok, "BigCommerce is not enabled for this store id."}

      err ->
        err
    end
  end

  @spec update(params :: map()) :: {:ok, String.t()} | {:error, any()}
  def update(%{"user_id" => user_id} = params) do
    with {:ok, true} <- is_big_commerce_enabled?(user_id),
         {:ok, _product_id} <- BigCommerceAPI.update(params) do
      {:ok, :updated_successfully}
    else
      false ->
        {:ok, "BigCommerce is not enabled for this user id."}

      err ->
        err
    end
  end

  @spec delete(session :: map(), sku :: String.t()) :: {:ok, String.t()} | {:error, any()}
  def delete(session, sku) do
    with %Offer{bc_product_id: product_id} when not is_nil(product_id) <-
           Offers.get_offer_by_sku(sku, session),
         {:ok, :success} <- BigCommerceAPI.delete(session, product_id) do
      {:ok, :deleted_big_commerce_inventory}
    else
      %Offer{bc_product_id: nil} ->
        {:ok, :skipped_big_commerce_deletion}

      _ ->
        {:ok, :skipped_big_commerce_deletion}
    end
  end

  @spec is_big_commerce_enabled?(user_id :: String.t()) :: {:ok, Boolean.t()}
  def is_big_commerce_enabled?(user_id) do
    query = from bc in BigCommerce, where: bc.user_id == ^user_id and bc.active == true
    {:ok, Repo.exists?(query)}
  end

  @spec get_big_commerce_access_code_by_user_id(user_id :: String.t()) ::
          {:ok, String.t()} | {:error, :no_active_store_exists}
  def get_big_commerce_access_code_by_user_id(user_id) do
    query =
      from bcs in BigCommerceSession,
        where: bcs.user_id == ^user_id,
        order_by: [desc: :updated_at],
        limit: 1

    case Repo.one(query) do
      nil ->
        {:error, :no_active_store_exists}

      %BigCommerceSession{access_token: token} ->
        {:ok, token}
    end
  end

  @spec get_store_url_by_user_id(user_id :: String.t()) ::
          {:ok, String.t()} | {:error, :no_active_store_exists}
  def get_store_url_by_user_id(user_id) do
    query =
      from b in BigCommerce,
        where: b.user_id == ^user_id and b.active == true,
        order_by: [desc: :updated_at],
        limit: 1

    case Repo.one(query) do
      nil ->
        {:error, :no_active_store_exists}

      %BigCommerce{store_url: url} ->
        {:ok, url}
    end
  end

  defp has_big_commerce_fields?(%{"inventory" => %{"product" => product}}) do
    Map.has_key?(product, "bc_fields") && Enum.count(Map.keys(product["bc_fields"])) > 0
  end

  def update_big_commerce_product_id(params, product_id) do
    with {:ok, _} <- update_bc_product(params, product_id),
         {:ok, _} <- update_bc_offers(params, product_id) do
      {:ok, :success}
    end
  end

  def update_bc_product(%{"sku" => sku, "user_id" => user_id}, _) do
    case Repo.get_by(Product, sku: sku, user_id: user_id) do
      nil ->
        {:error, :failed_no_product_with_sku}

      product ->
        changes = Ecto.Changeset.change(product, bc_submitted: true)
        Repo.update(changes)
        {:ok, :success}
    end
  end

  def update_bc_offers(%{"sku" => sku, "user_id" => user_id}, product_id) do
    case Repo.get_by(Offer, sku: sku, user_id: user_id) do
      nil ->
        {:error, :failed_no_offer_with_sku}

      offer ->
        changes = Ecto.Changeset.change(offer, bc_product_id: product_id)
        Repo.update(changes)
        {:ok, :success}
    end
  end
end
