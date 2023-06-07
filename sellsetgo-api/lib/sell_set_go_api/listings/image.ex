defmodule SellSetGoApi.Listings.Image do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.User
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "images" do
    field(:provider, :string, default: "EBAY")
    field(:provider_image_url, :string)
    field(:order, :integer, default: 999)
    field(:s3_url, :string)
    field(:sku, :string)
    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:s3_url, :provider, :provider_image_url, :order, :user_id, :sku])
    |> validate_required([:s3_url, :provider, :order, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  def changeset_valid_for_all?(image, attrs) do
    for attrs <- attrs do
      changeset(image, attrs).valid?
    end
    |> Enum.all?()
  end
end
