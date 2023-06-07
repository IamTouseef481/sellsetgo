defmodule SellSetGoApi.Accounts.DescriptionTemplate do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "description_templates" do
    field(:name, :string)
    field(:template, :string)
    belongs_to(:user, SellSetGoApi.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:name, :template, :user_id])
    |> unique_constraint([:name, :user_id])
  end

  Protocol.derive(Jason.Encoder, SellSetGoApi.Accounts.DescriptionTemplate,
    only: [:id, :name, :template, :user_id, :inserted_at, :updated_at]
  )
end
