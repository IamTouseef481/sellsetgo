defmodule SellSetGoApiWeb.InventoryLocationView do
  use SellSetGoApiWeb, :view

  def render("index.json", %{data: data}) do
    %{data: data}
  end
end
