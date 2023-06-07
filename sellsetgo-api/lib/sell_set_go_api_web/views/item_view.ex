defmodule SellSetGoApiWeb.ItemView do
  use SellSetGoApiWeb, :view

  def render("item_index.json", %{item_lists: item_lists}) do
    %{data: item_lists}
  end

  def render("quantity_sold.json", %{quantity_sold: quantity_sold}) do
    %{data: %{quantity_sold: quantity_sold}}
  end
end
