defmodule SellSetGoApi.Admin.Category do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admin_categories" do
    field(:categories, :map)
    field(:provider, :string)
    field(:category_tree_id, :string)
    field(:category_tree_version, :string)

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:provider, :category_tree_id, :category_tree_version, :categories])
    |> validate_required([:provider, :category_tree_id, :category_tree_version, :categories])
  end
end
