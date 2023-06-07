defmodule SellSetGoApiWeb.UpdateSaleQtyController do
  use SellSetGoApiWeb, :controller

  action_fallback SellSetGoApiWeb.FallbackController

  alias SellSetGoApi.UpdateSaleQty
  alias SellSetGoApi.Inventory.Product
  alias SellSetGoApi.Offers.Offer

  def update(conn, %{"username" => username, "data" => attrs}) do
    sku = attrs["sku"]
    quantity_purchased = attrs["quantityPurchased"]
    with {:ok, user_id} <- UpdateSaleQty.get_userid_by_username(username),
      {:ok, %Product{quantity: updated_qty}} <- UpdateSaleQty.update_sale_quantity_on_products(user_id, sku, quantity_purchased),
      {:ok, %Offer{} = _offer} <- UpdateSaleQty.update_sale_quantity_on_offers(user_id, sku, updated_qty)
    do
      conn
      |> render("index.json", data: "#{updated_qty}, Quantity Updated Successully!")
    end
  end
end
