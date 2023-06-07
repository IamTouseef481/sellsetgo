defmodule SellSetGoApi.Repo.Migrations.Reports do
  use Ecto.Migration

  def change do
    create table(:reports, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:type, :string)
      add(:file_name, :string)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      timestamps()
    end

    create(index(:reports, [:user_id]))
    create(unique_index(:reports, [:user_id, :file_name]))
  end
end
