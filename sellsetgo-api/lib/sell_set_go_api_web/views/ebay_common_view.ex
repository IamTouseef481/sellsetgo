defmodule SellSetGoApiWeb.EbayCommonView do
  use SellSetGoApiWeb, :view
  alias SellSetGoApi.Utils

  def render("index.json", %{result: result}) do
    %{
      data: result
    }
  end

  def render("admin_categories.json", %{admin_categories: admin_categories}) do
    categories = Map.get(admin_categories, :categories)["children"]
    keys = %{name: "name", children: "children", id: "id", parent: "parent", level: "level"}

    %{
      data: Utils.format_categories(categories, keys)
    }
  end
end
