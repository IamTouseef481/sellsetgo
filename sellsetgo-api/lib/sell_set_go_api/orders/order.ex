defmodule SellSetGoApi.Orders.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol
  alias SellSetGoApi.Accounts.User

  @derive {Jason.Encoder,
           only: [
             :id,
             :order_id,
             :creation_date,
             :last_modified_date,
             :order_fulfillment_status,
             :order_payment_status,
             :seller_id,
             :buyer,
             :pricing_summary,
             :payments,
             :fulfillment_instructions,
             :line_items,
             :sales_record_ref,
             :tracking_details,
             :user_id
           ]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "orders" do
    field(:order_id, :string)
    field(:creation_date, :utc_datetime)
    field(:last_modified_date, :utc_datetime)
    field(:order_fulfillment_status, :string)
    field(:order_payment_status, :string)
    field(:seller_id, :string)
    field(:buyer, :map)
    field(:pricing_summary, :map)
    field(:payments, :map)
    field(:fulfillment_instructions, {:array, :map})
    field(:line_items, {:array, :map})
    field(:sales_record_ref, :string)
    field(:tracking_details, {:array, :map})
    belongs_to(:user, User)

    timestamps()
  end

  @required_fields [:buyer, :pricing_summary, :payments, :fulfillment_instructions, :line_items]
  @optional_fields [
    :order_id,
    :creation_date,
    :last_modified_date,
    :order_fulfillment_status,
    :order_payment_status,
    :seller_id,
    :sales_record_ref,
    :tracking_details,
    :user_id
  ]
  @order_fulfillment_status_type ["FULFILLED", "IN_PROGRESS", "NOT_STARTED"]
  @order_payment_status_type ["FAILED", "FULLY_REFUNDED", "PAID", "PARTIALLY_REFUNDED", "PENDING"]

  def changeset(order, attrs) do
    order
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:order_fulfillment_status, @order_fulfillment_status_type)
    |> validate_inclusion(:order_payment_status, @order_payment_status_type)
  end
end
