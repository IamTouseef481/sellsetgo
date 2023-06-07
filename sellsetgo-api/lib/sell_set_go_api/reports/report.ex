defmodule SellSetGoApi.Report do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol
  alias SellSetGoApi.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "reports" do
    field(:type, :string)
    field(:file_name, :string)
    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @types [
    "items",
    "item_specifics",
    "bulk_price_qty_response",
    "bulk_update",
    "bulk_create_response"
  ]

  def changeset(offer, attrs) do
    offer
    |> cast(attrs, [
      :type,
      :file_name,
      :user_id
    ])
    |> validate_required([:type, :file_name, :user_id])
    |> validate_inclusion(:type, @types)
  end

  Protocol.derive(Jason.Encoder, __MODULE__,
    only: [
      :type,
      :file_name,
      :inserted_at
    ]
  )
end
