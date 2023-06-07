defmodule SellSetGoApi.Inventory.Product do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol
  alias SellSetGoApi.Accounts.User
  alias SellSetGoApi.Inventory.{Data}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field(:aspects, :map)
    field(:condition, :string)
    field(:description, :string)
    field(:image_ids, {:array, :string})
    field(:is_submitted, :boolean, default: false)
    field(:package_weight_and_size, :map)
    field(:quantity, :integer)
    field(:sku, :string)
    field(:status, :string)
    field(:title, :string)
    field(:ean, {:array, :string})
    field(:isbn, {:array, :string})
    field(:mpn, :string)
    field(:upc, {:array, :string})
    field(:vehicle_compatibility, :map)
    field(:bc_fields, :map)
    field(:bc_submitted, :boolean, default: false)
    field(:variant_skus, {:array, :string})
    field(:aspects_image_varies_by, {:array, :string})
    field(:specifications, {:array, :map})

    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @condition_enum_values %{
    "1000" => "NEW",
    "1500" => "NEW_OTHER",
    "1750" => "NEW_WITH_DEFECTS",
    "2000" => "CERTIFIED_REFURBISHED",
    "2010" => "EXCELLENT_REFURBISHED",
    "2020" => "VERY_GOOD_REFURBISHED",
    "2030" => "GOOD_REFURBISHED",
    "2500" => "SELLER_REFURBISHED",
    "2750" => "LIKE_NEW",
    "3000" => "USED_EXCELLENT",
    "4000" => "USED_VERY_GOOD",
    "5000" => "USED_GOOD",
    "6000" => "USED_ACCEPTABLE",
    "7000" => "FOR_PARTS_OR_NOT_WORKING"
  }

  @status ~w(active draft ended)
  @doc false
  def changeset(product, attrs) do
    product
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
      :variant_skus,
      :aspects_image_varies_by,
      :specifications
    ])
    |> validate_required([:sku, :status, :user_id])
    |> validate_inclusion(:status, @status)
    |> validate_inclusion(:condition, Data.get_condition_enum())
    |> validate_sku_by_status(product)
    |> unique_constraint([:sku, :user_id])
  end

  def changeset_valid_for_all?(product, attrs) do
    for attrs <- attrs do
      changeset(product, attrs).valid?
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
  def get_condition_enums, do: @condition_enum_values

  Protocol.derive(Jason.Encoder, __MODULE__,
    only: [
      :id,
      :aspects,
      :condition,
      :description,
      :image_ids,
      :images,
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
      :variant_skus,
      :aspects_image_varies_by,
      :specifications
    ]
  )
end
