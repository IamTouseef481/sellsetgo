defmodule SellSetGoApi.Accounts.UserSetting do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.User
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "user_settings" do
    field(:notification_settings, {:array, :map}, default: [])

    belongs_to(:user, User)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :notification_settings
    ])
    |> validate_required([:user_id])
  end
end
