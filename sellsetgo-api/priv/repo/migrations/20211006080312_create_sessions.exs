defmodule SellSetGoApi.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_access_token, :text)
      add(:user_access_token_expires_at, :utc_datetime)
      add(:refresh_token, :text)
      add(:refresh_token_expires_at, :utc_datetime)
      add(:last_refreshed_at, :utc_datetime)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))

      timestamps()
    end

    create(index(:sessions, [:user_id]))
  end
end
