defmodule SellSetGoApi.Repo.Migrations.CreateAdminCategories do
  use Ecto.Migration

  def change do
    create table(:admin_categories, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:provider, :string)
      add(:category_tree_id, :string)
      add(:category_tree_version, :string)
      add(:categories, :map)

      timestamps()
    end

    create(unique_index(:admin_categories, [:provider, :category_tree_id]))
    create(index(:admin_categories, [:categories], using: :gin))
    create(index(:admin_categories, [:category_tree_id]))
  end
end
