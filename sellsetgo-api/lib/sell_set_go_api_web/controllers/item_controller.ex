defmodule SellSetGoApiWeb.ItemController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.{Items, OauthEbay, Utils}

  action_fallback(SellSetGoApiWeb.FallbackController)

  def index(%{assigns: %{current_session_record: current_session_record}} = conn, params) do
    with client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory_item"),
             current_session_record
           ),
         {:ok, route} <- Items.get_route(params),
         {:ok, %OAuth2.Response{body: item_lists}} <- OAuth2.Client.get(client, route) do
      conn
      |> render("item_index.json", item_lists: item_lists)
    end
  end

  def get_quantity_sold(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "resource_name" => "item_sold",
          "listing_id" => item_id,
          "marketplace_id" => marketplace_id
        }
      ) do
    quantity_sold = Items.get_quantity_sold(current_session_record, item_id, marketplace_id)

    conn
    |> render("quantity_sold.json", quantity_sold: quantity_sold)
  end
end
