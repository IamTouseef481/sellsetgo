defmodule SellSetGoApi.Repo.Migrations.MessageFetchTimes do
  use Ecto.Migration

  def change do
    create table(:message_fetch_times, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:last_fetched_at, :utc_datetime)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      timestamps()
    end

    create(unique_index(:message_fetch_times, [:user_id]))
  end
end
