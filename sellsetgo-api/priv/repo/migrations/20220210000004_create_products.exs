defmodule SellSetGoApi.Repo.Migrations.CreateProductsAndAlteroffers do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string)
      add(:aspects, :map)
      add(:description, :string)
      add(:image_ids, {:array, :string})
      add(:condition, :string)
      add(:package_specs, :map)
      add(:quantity, :integer)
      add(:status, :string)
      add(:sku, :string)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      timestamps()
    end

    create(index(:products, [:title]))
    create(unique_index(:products, [:sku]))

    alter table(:offers) do
      remove(:listing_fees)
      add(:sku, :string)
    end
  end
end
