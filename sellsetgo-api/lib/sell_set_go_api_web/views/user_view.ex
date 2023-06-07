defmodule SellSetGoApiWeb.UserView do
  use SellSetGoApiWeb, :view
  alias SellSetGoApi.Utils
  alias SellSetGoApiWeb.UserView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      data: %{
        id: user.id,
        username: user.username,
        account_type: user.account_type,
        site: user.site,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      }
    }
  end

  def render("store_categories.json", %{store_categories: store_categories}) do
    %{
      data: render_many(store_categories, UserView, "store_category.json", as: :store_category)
    }
  end

  def render("store_category.json", %{store_category: store_category}) do
    categories = Map.get(store_category, :categories)

    keys = %{
      name: "name",
      id: "category_id",
      parent: "parent_id",
      level: "order",
      children: "child_categories"
    }

    %{
      "store_categories" => Utils.format_categories(categories["custom_category"], keys)
    }
  end

  def render("inventory_locations.json", %{inventory_locations: inventory_locations}) do
    %{data: inventory_locations}
  end
end
