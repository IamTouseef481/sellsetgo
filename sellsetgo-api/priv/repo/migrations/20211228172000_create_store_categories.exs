defmodule SellSetGoApi.Repo.Migrations.CreateStoreCategories do
  use Ecto.Migration

  def change do
    create table(:store_categories, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:categories, :map)
      add(:store_name, :string)
      add(:user_id, references("users", on_delete: :delete_all, type: :string))

      timestamps()
    end

    create(unique_index(:store_categories, [:user_id, :store_name]))
  end
end
