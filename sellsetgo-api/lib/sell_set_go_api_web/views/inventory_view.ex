defmodule SellSetGoApiWeb.InventoryView do
  use SellSetGoApiWeb, :view

  def render("product.json", %{product: product}) when not is_nil(product.variant_skus) do
    Map.drop(product, [:__meta__, :__struct__, :user])
  end

  def render("product.json", %{product: product}) do
    %{data: product}
  end

  def render("grid_collection.json", %{
        product: product,
        total_entries: total_entries,
        total_pages: total_pages
      }) do
    %{data: product, total_entries: total_entries, total_pages: total_pages}
  end
end
