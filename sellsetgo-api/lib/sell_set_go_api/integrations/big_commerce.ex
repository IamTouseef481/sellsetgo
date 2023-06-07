defmodule SellSetGoApi.Integrations.BigCommerce do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.User
  @derive {Jason.Encoder, only: [:store_url, :active, :id]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "big_commerce_integrations" do
    field(:active, :boolean, default: false)
    field(:store_url, :string)
    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @doc false
  def changeset(ecommerce, attrs) do
    ecommerce
    |> cast(attrs, [:store_url, :active, :user_id])
    |> validate_required([:store_url, :active, :user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :store_url, :active])
  end
end
