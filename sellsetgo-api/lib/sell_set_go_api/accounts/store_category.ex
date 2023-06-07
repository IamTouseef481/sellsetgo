defmodule SellSetGoApi.Accounts.StoreCategory do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "store_categories" do
    field(:categories, :map)
    field(:store_name, :string)
    belongs_to(:user, SellSetGoApi.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:categories, :user_id, :store_name])
    |> validate_required([:categories, :user_id, :store_name])
    |> validate_length(:store_name, max: 100)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :store_name])
  end
end
