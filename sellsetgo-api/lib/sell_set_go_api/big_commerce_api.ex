defmodule SellSetGoApi.BigCommerceAPI do
  @moduledoc """
  BigCommerce API related functions are defined here
  """
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://api.bigcommerce.com/stores/")

  plug(Tesla.Middleware.Headers, [
    {"accept", "application/json"},
    {"content-type", "application/json"}
  ])

  plug(Tesla.Middleware.JSON)

  alias SellSetGoApi.BigCommerceIntegrations
  alias SellSetGoApi.Inventory.BigCommerceInvertory.BigCommerce, as: BigCommerceStruct
  alias SellSetGoApi.Listings
  alias SellSetGoApi.Oauth.BigCommerce

  @api_uri "/v3/catalog/products"

  @spec create(params :: map()) :: {:ok, String.t()} | {:error, any()}
  def create(%{"user_id" => user_id} = params) do
    with {:ok, token} <- BigCommerceIntegrations.get_big_commerce_access_code_by_user_id(user_id),
         {:ok, store_url} <- BigCommerceIntegrations.get_store_url_by_user_id(user_id),
         {:ok, images} <- get_image_urls(params),
         {:ok, params} <-
           BigCommerceStruct.parse_params(Map.merge(params, %{"images" => images})),
         {:ok, %Tesla.Env{body: %{"data" => %{"id" => product_id}}}} <-
           post(
             "#{BigCommerce.get_store_hash(store_url)}#{@api_uri}",
             params,
             headers: [{"x-auth-token", token}]
           ) do
      {:ok, product_id}
    else
      {:ok, %Tesla.Env{body: _}} ->
        {:error, :failed_to_push_inventaroy_to_big_commerce}

      {:error, :invalid_params_passed} ->
        {:error, :failed_to_push_invalid_params}

      err ->
        err
    end
  end

  @spec update(params :: map()) :: {:ok, String.t()} | {:error, any()}
  def update(%{"user_id" => user_id, "product_id" => product_id} = params) do
    with {:ok, token} <- BigCommerceIntegrations.get_big_commerce_access_code_by_user_id(user_id),
         {:ok, store_url} <- BigCommerceIntegrations.get_store_url_by_user_id(user_id),
         {:ok, images} <- get_image_urls(params),
         {:ok, params} <-
           BigCommerceStruct.parse_params(Map.merge(params, %{"images" => images})),
         {:ok, %Tesla.Env{body: %{"data" => %{"id" => _product_id}}}} <-
           put(
             "#{BigCommerce.get_store_hash(store_url)}#{@api_uri}/#{product_id}",
             params,
             headers: [{"x-auth-token", token}]
           ) do
      {:ok, ""}
    else
      {:ok, %Tesla.Env{body: _}} ->
        {:error, :failed_to_push_inventaroy_to_big_commerce}

      {:error, :invalid_params_passed} ->
        {:error, :failed_to_push_invalid_params}

      err ->
        err
    end
  end

  @spec delete(session :: map(), product_id :: String.t()) :: {:ok, String.t()} | {:error, any()}
  def delete(%{user_id: user_id}, product_id) do
    with {:ok, token} <- BigCommerceIntegrations.get_big_commerce_access_code_by_user_id(user_id),
         {:ok, store_url} <- BigCommerceIntegrations.get_store_url_by_user_id(user_id),
         {:ok, %Tesla.Env{status: 204}} <-
           delete(
             "#{BigCommerce.get_store_hash(store_url)}#{@api_uri}/#{product_id}",
             headers: [{"x-auth-token", token}]
           ) do
      {:ok, :success}
    else
      {:ok, %Tesla.Env{body: _}} ->
        {:error, :failed_to_delete_inventaroy_from_big_commerce}

      err ->
        err
    end
  end

  def get_image_urls(%{"sku" => sku}) do
    sku
    |> Listings.get_bc_image_urls()
    |> case do
      nil ->
        {:ok, []}

      images ->
        {:ok,
         Enum.map(images, fn %{s3_url: url} -> %{"image_url" => url, "is_thumbnail" => true} end)}
    end
  end
end
