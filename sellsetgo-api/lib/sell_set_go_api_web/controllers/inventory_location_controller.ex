defmodule SellSetGoApiWeb.InventoryLocationController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.InventoryLocation

  action_fallback SellSetGoApiWeb.FallbackController

  def index(conn, _params) do
    session = SellSetGoApi.get_session(conn)

    with {:ok, %OAuth2.Response{body: response}} <-
      InventoryLocation.ebay_list_inventory_locations(session) do
      conn
      |> render("index.json", data: response)
    end
  end

  def create(conn, attrs) do
    session = SellSetGoApi.get_session(conn)

    with {:ok, %OAuth2.Response{body: _body}} <-
      InventoryLocation.ebay_create_inventory_location(session, attrs) do
      conn
      |> put_status(:created)
      |> render("index.json", data: "Inventory Location Created")
    end
  end

  def update(conn, attrs) do
    session = SellSetGoApi.get_session(conn)

    with {:ok, %OAuth2.Response{body: _body}} <-
      InventoryLocation.ebay_update_inventory_location(session, attrs) do
      conn
      |> render("index.json", data: "Inventory Location Updated")
    end
  end

  def delete(conn, %{"merchantLocationKey" => merchant_location_key}) do
    session = SellSetGoApi.get_session(conn)

    with {:ok, %OAuth2.Response{body: _body}} <-
      InventoryLocation.ebay_delete_inventory_location(session, merchant_location_key) do
      send_resp(conn, :no_content, "")
    end
  end
end
