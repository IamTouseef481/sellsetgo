defmodule SellSetGoApi.Accounts.ProfileDetails do
  use Ecto.Schema
  alias SellSetGoApi.Accounts.ProfileDetails
  import Ecto.Changeset
  @moduledoc false

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    field :mobile_number, :string
  end

  def changeset(%ProfileDetails{} = profile_details, attrs \\ %{}) do
    profile_details
    |> cast(attrs, [:name, :email, :mobile_number])
  end
end
