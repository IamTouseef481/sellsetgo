defmodule SellSetGoApi.Integrations.BigCommerceSession do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.User
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "big_commerce_sessions" do
    field(:access_token, :string)
    field(:other_params, :map)
    belongs_to(:user, User, type: :string)

    timestamps()
  end

  @doc false
  def changeset(big_commerce_session, attrs) do
    big_commerce_session
    |> cast(attrs, [:access_token, :other_params, :user_id])
    |> validate_required([:access_token, :other_params, :user_id])
  end
end
