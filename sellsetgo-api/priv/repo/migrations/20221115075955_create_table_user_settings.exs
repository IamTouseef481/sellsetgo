defmodule SellSetGoApi.Repo.Migrations.CreateTableUserSettings do
  use Ecto.Migration

  def change do
    create table(:user_settings, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      add(:notification_settings, :map)
    end

    create(unique_index(:user_settings, [:user_id]))
  end
end
