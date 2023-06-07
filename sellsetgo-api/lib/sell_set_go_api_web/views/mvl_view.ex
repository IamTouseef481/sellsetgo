defmodule SellSetGoApiWeb.MVLView do
  use SellSetGoApiWeb, :view

  def render("product.json", %{product: product}) do
    %{data: product}
  end
end
