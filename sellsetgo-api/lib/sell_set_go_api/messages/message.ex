defmodule SellSetGoApi.Messages.Message do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  require Protocol

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field(:email_json, :map)
    field(:body, :string)
    field(:parent_id, :string)
    field(:message_id, :string)
    field(:sender_id, :string)
    field(:subject, :string)
    field(:created_date, :utc_datetime)
    field(:message_type, :string)
    field(:is_answered, :boolean, default: false)
    field(:is_read, :boolean, default: false)
    belongs_to(:user, SellSetGoApi.Accounts.User, type: :string)

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [
      :email_json,
      :body,
      :parent_id,
      :message_id,
      :user_id,
      :sender_id,
      :subject,
      :created_date,
      :message_type,
      :is_answered,
      :is_read
    ])
    |> validate_required([:message_id, :user_id, :sender_id, :subject, :created_date])
    |> validate_required_email_json()
    |> validate_inclusion(:message_type, ["received", "sent"])
    |> foreign_key_constraint(:user_id)
  end

  defp validate_required_email_json(
         %Ecto.Changeset{changes: %{message_type: "received"}} = changeset
       ) do
    changeset
    |> validate_required([:email_json])
  end

  defp validate_required_email_json(changeset), do: changeset

  Protocol.derive(Jason.Encoder, __MODULE__,
    only: [
      :id,
      :message_id,
      :email_json,
      :parent_id,
      :body,
      :sender_id,
      :subject,
      :created_date,
      :message_type,
      :is_answered,
      :is_read
    ]
  )
end
