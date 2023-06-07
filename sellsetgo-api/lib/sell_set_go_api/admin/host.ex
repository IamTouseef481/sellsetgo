defmodule SellSetGoApi.Admin.Host do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admin_hosts" do
    field(:name, :string, null: false)
    field(:prod_host, :string, null: false)
    field(:provider, :string, default: "EBAY")
    field(:sandbox_host, :string, null: false)

    timestamps()
  end

  @doc false
  def changeset(host, attrs) do
    host
    |> cast(attrs, [:provider, :name, :prod_host, :sandbox_host])
    |> validate_required([:provider, :name, :prod_host, :sandbox_host])
  end
end
