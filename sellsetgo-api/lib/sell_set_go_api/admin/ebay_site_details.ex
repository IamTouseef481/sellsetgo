defmodule SellSetGoApi.Admin.EbaySiteDetails do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admin_ebay_site_details" do
    field(:global_id, :string)
    field(:language, :string)
    field(:name, :string)
    field(:site_id, :integer)
    field(:status, :string)
    field(:territory, :string)
    field(:currency, :string)
    field(:domain, :string)
    field(:currency_symbol, :string)

    timestamps()
  end

  @required_field [
    :site_id,
    :global_id,
    :language,
    :territory,
    :name,
    :status,
    :currency,
    :domain,
    :currency_symbol
  ]
  @doc false
  def changeset(ebay_site_details, attrs) do
    ebay_site_details
    |> cast(attrs, @required_field)
    |> validate_required(@required_field)
    |> unique_constraint([:site_id, :global_id])
  end
end
