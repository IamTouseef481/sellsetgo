defmodule SellSetGoApi.InventoryLocation do
  @moduledoc """
  The InventoryLocation context.
  """
  @ebay_endpoints Application.get_env(:sell_set_go_api, :ebay_endpoints)
  alias SellSetGoApi.OauthEbay

  @doc """
  Returns the list of inventory locations.

  ## Examples

      iex> ebay_list_inventory_locations(%{field: value})
      {:ok, %OAuth2.Response{}}

  """
  def ebay_list_inventory_locations(session) do
    api_url = @ebay_endpoints[:inventory_location] <> "/?limit=100&offset=0"

    "Bearer"
    |> OauthEbay.get_client_by_session(session)
    |> OAuth2.Client.get(api_url)
  end

  @doc """
  Creates a inventory location.

  ## Examples

      iex> ebay_create_inventory_location(%{field: value}, %{"field" => value})
      {:ok, %OAuth2.Response{}}

      iex> ebay_create_inventory_location(%{field: value}, %{"field" => value})
      {:error, %OAuth2.Response{}}

  """
  def ebay_create_inventory_location(session, %{"merchantLocationKey" => merchant_location_key} = attrs) do
    api_url = @ebay_endpoints[:inventory_location] <> "/#{merchant_location_key}"

    "Bearer"
    |> OauthEbay.get_client_by_session(session)
    |> OAuth2.Client.put_header("content-type", "application/json")
    |> OAuth2.Client.post(api_url, attrs)
  end

  @doc """
  Update a inventory location.

  ## Examples

      iex> ebay_update_inventory_location(%{field: value}, %{"field" => value})
      {:ok, %OAuth2.Response{}}

      iex> ebay_update_inventory_location(%{field: value}, %{"field" => value})
      {:error, %OAuth2.Response{}}

  """
  def ebay_update_inventory_location(session, %{"merchantLocationKey" => merchant_location_key} = attrs) do
    api_url = @ebay_endpoints[:inventory_location] <> "/#{merchant_location_key}/update_location_details"

    "Bearer"
    |> OauthEbay.get_client_by_session(session)
    |> OAuth2.Client.put_header("content-type", "application/json")
    |> OAuth2.Client.post(api_url, attrs)
  end

  @doc """
  Delete a inventory location.

  ## Examples

      iex> ebay_delete_inventory_location(%{field: value}, %{"field" => value})
      {:ok, %OAuth2.Response{}}

      iex> ebay_delete_inventory_location(%{field: value}, %{"field" => value})
      {:error, %OAuth2.Response{}}

  """
  def ebay_delete_inventory_location(session, merchant_location_key) do
    api_url = @ebay_endpoints[:inventory_location] <> "/#{merchant_location_key}"

    "Bearer"
    |> OauthEbay.get_client_by_session(session)
    |> OAuth2.Client.put_header("content-type", "application/json")
    |> OAuth2.Client.delete(api_url)
  end
end
