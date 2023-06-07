defmodule SellSetGoApi.Offers.VariationOffer do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol
  alias SellSetGoApi.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "variation_offers" do
    field(:is_submitted, :boolean, default: false)
    field(:last_verified_at, :string)
    field(:listing_id, :string)
    field(:offer_detail, :map)
    field(:offer_id, :string)
    field(:published_at, :string)
    field(:revised_at, :string)
    field(:sku, :string)
    field(:status, :string)
    field(:marketplace_id, :string)
    field(:bc_product_id, :integer)
    field(:parent_sku, :string)

    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @doc false
  def changeset(variation_offer, attrs) do
    variation_offer
    |> cast(attrs, [
      :is_submitted,
      :last_verified_at,
      :listing_id,
      :offer_detail,
      :offer_id,
      :published_at,
      :revised_at,
      :sku,
      :status,
      :user_id,
      :marketplace_id,
      :bc_product_id,
      :parent_sku
    ])
    |> validate_required([:offer_detail, :sku, :status, :user_id, :parent_sku])
    |> validate_inclusion(:status, ["active", "draft", "ended", "verified"])
  end

  def changeset_valid_for_all?(variation_offer, attrs) do
    for attrs <- attrs do
      changeset(variation_offer, attrs).valid?
    end
    |> Enum.all?()
  end

  Protocol.derive(Jason.Encoder, __MODULE__,
    only: [
      :id,
      :is_submitted,
      :marketplace_id,
      :last_verified_at,
      :listing_id,
      :offer_detail,
      :offer_id,
      :published_at,
      :revised_at,
      :sku,
      :status,
      :bc_product_id
    ]
  )
end
