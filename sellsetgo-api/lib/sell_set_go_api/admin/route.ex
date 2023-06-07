defmodule SellSetGoApi.Admin.Route do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admin_routes" do
    field :name, :string
    field :provider, :string, default: "EBAY"
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(route, attrs) do
    route
    |> cast(attrs, [:provider, :name, :url])
    |> validate_required([:provider, :name, :url])
  end
end
