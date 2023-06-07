defmodule SellSetGoApi.Inventory.BulkQtyPriceRevision do
  @moduledoc """
  This module is used to store the values from CSV bulk revision of qty and price and status of the revision
  """

  use Ecto.Schema
  import Ecto.Changeset
  require Protocol
  alias SellSetGoApi.Utils

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bulk_qty_price_revisions" do
    field(:sku, :string)
    field(:item_id, :string)
    field(:price, :string)
    field(:warehouse_qty, :string)
    field(:ebay_qty, :string)
    field(:status, :string)
    field(:offer_id, :string)
    belongs_to(:user, SellSetGoApi.Accounts.User, type: :string)

    timestamps()
  end

  def changeset(bulk_qty_price_revision, %{"sku" => sku, "item_id" => item_id} = attrs) do
    bulk_qty_price_revision
    |> cast(attrs, [
      :price,
      :warehouse_qty,
      :ebay_qty,
      :status,
      :user_id
    ])
    |> check_sku_item_id(sku, item_id)
  end

  defp check_sku_item_id(changeset, sku, item_id) do
    cond do
      Utils.is_empty?(sku) and Utils.is_empty?(item_id) ->
        add_error(changeset, :sku_or_item_id, "empty")

      Utils.is_empty?(sku) and !Utils.is_empty?(item_id) ->
        put_change(changeset, :item_id, item_id)

      !Utils.is_empty?(sku) and Utils.is_empty?(item_id) ->
        put_change(changeset, :sku, sku)

      !Utils.is_empty?(sku) and !Utils.is_empty?(item_id) ->
        put_change(changeset, :sku, sku)
        |> put_change(:item_id, item_id)
    end
  end

  Protocol.derive(Jason.Encoder, __MODULE__,
    only: [
      :sku,
      :item_id,
      :price,
      :warehouse_qty,
      :ebay_qty,
      :status,
      :user_id
    ]
  )
end
