defmodule SellSetGoApi.Accounts.Session do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.User
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "sessions" do
    field(:last_refreshed_at, :utc_datetime)
    field(:refresh_token, :string)
    field(:refresh_token_expires_at, :utc_datetime)
    field(:user_access_token, :string)
    field(:user_access_token_expires_at, :utc_datetime)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :user_access_token,
      :user_access_token_expires_at,
      :refresh_token,
      :refresh_token_expires_at,
      :last_refreshed_at
    ])
    |> validate_required([
      :user_access_token,
      :user_access_token_expires_at,
      :refresh_token,
      :refresh_token_expires_at,
      :last_refreshed_at
    ])
  end
end
