defmodule SellSetGoApi.Repo.Migrations.Messages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:email_json, :map)
      add(:parent_id, :string)
      add(:message_id, :string)
      add(:sender_id, :string)
      add(:subject, :string)
      add(:created_date, :utc_datetime)
      add(:message_type, :string)
      add(:is_answered, :boolean)
      add(:is_read, :boolean)
      add(:body, :string)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      timestamps()
    end

    create(index(:messages, [:user_id]))
    create(unique_index(:messages, [:message_id]))
  end
end
