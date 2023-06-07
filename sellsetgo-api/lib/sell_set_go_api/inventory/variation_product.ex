defmodule SellSetGoApi.Inventory.VariationProduct do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol
  alias SellSetGoApi.Accounts.User
  alias SellSetGoApi.Inventory.{Data}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "variation_products" do
    field(:title, :string)
    field(:aspects, :map)
    field(:condition, :string)
    field(:description, :string)
    field(:image_ids, {:array, :string})
    field(:is_submitted, :boolean, default: false)
    field(:package_weight_and_size, :map)
    field(:quantity, :integer)
    field(:sku, :string)
    field(:status, :string)
    field(:ean, {:array, :string})
    field(:isbn, {:array, :string})
    field(:mpn, :string)
    field(:upc, {:array, :string})
    field(:vehicle_compatibility, :map)
    field(:bc_fields, :map)
    field(:bc_submitted, :boolean, default: false)
    field(:parent_sku, :string)

    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @status ~w(active draft ended)
  @doc false
  def changeset(variation_product, attrs) do
    variation_product
    |> cast(attrs, [
      :aspects,
      :condition,
      :description,
      :image_ids,
      :is_submitted,
      :package_weight_and_size,
      :quantity,
      :sku,
      :status,
      :title,
      :user_id,
      :ean,
      :isbn,
      :mpn,
      :upc,
      :vehicle_compatibility,
      :bc_fields,
      :bc_submitted,
      :parent_sku
    ])
    |> validate_required([:sku, :status, :user_id, :parent_sku])
    |> validate_inclusion(:status, @status)
    |> validate_inclusion(:condition, Data.get_condition_enum())
    |> validate_sku_by_status(variation_product)
    |> unique_constraint([:sku, :user_id])
  end

  def changeset_valid_for_all?(variation_product, attrs) do
    for attrs <- attrs do
      changeset(variation_product, attrs).valid?
    end
    |> Enum.all?()
  end

  defp validate_sku_by_status(%Ecto.Changeset{changes: %{sku: _sku}} = changeset, product) do
    if Map.get(product, "status") == "active" || Map.get(product, :status) == "active" do
      add_error(changeset, :sku, "Product is active, So 'SKU' cannot be changed")
    else
      changeset
    end
  end

  defp validate_sku_by_status(changeset, _product), do: changeset

  Protocol.derive(Jason.Encoder, __MODULE__,
    only: [
      :id,
      :aspects,
      :condition,
      :description,
      :image_ids,
      :is_submitted,
      :package_weight_and_size,
      :quantity,
      :sku,
      :status,
      :title,
      :user_id,
      :ean,
      :isbn,
      :mpn,
      :upc,
      :vehicle_compatibility,
      :bc_fields,
      :bc_submitted
    ]
  )
end
