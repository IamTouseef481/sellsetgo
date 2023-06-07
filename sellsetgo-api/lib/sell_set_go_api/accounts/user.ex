defmodule SellSetGoApi.Accounts.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.{Session, ProfileDetails}
  alias SellSetGoApi.Integrations.BigCommerce
  alias SellSetGoApi.Listings.Image
  alias SellSetGoApi.Offers.Offer

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "users" do
    field(:site, :string, null: false)
    field(:email, :string)
    field(:username, :string, null: false)
    field(:account_type, :string, null: false)
    field(:provider, :string, default: "EBAY")
    embeds_one :profile_details, ProfileDetails, on_replace: :delete

    has_many(:sessions, Session,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:images, Image,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:offers, Offer,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_one(:big_commerce, BigCommerce,
      on_delete: :delete_all,
      on_replace: :delete
    )

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :id,
      :site,
      :account_type,
      :provider
    ])
    |> cast_embed(:profile_details)
    |> unique_constraint(:email)
    |> validate_required([
      :username,
      :id,
      :site,
      :account_type
    ])
    |> cast_assoc(:sessions)
  end
end
