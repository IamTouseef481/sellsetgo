defmodule SellSetGoApi.LastFetchTime do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "last_fetch_times" do
    field(:last_fetched_at, :utc_datetime)
    field(:type, :string)
    belongs_to(:user, SellSetGoApi.Accounts.User, type: :string)

    timestamps()
  end

  @last_fetch_times_type ["message", "order"]
  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [
      :last_fetched_at,
      :type,
      :user_id
    ])
    |> validate_required([:last_fetched_at, :user_id])
    |> validate_inclusion(:type, @last_fetch_times_type)
    |> unique_constraint([:user_id, :type])
    |> foreign_key_constraint(:user_id)
  end

  Protocol.derive(Jason.Encoder, __MODULE__, only: [:id, :last_fetched_at, :type])
end
