defmodule SellSetGoApi.Repo.Migrations.CreateTableVariationProducts do
  use Ecto.Migration

  def change do
    create table(:variation_products, primary_key: false) do
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
      add(:is_submitted, :boolean)
      add(:ean, {:array, :string})
      add(:isbn, {:array, :string})
      add(:mpn, :string)
      add(:upc, {:array, :string})
      add(:vehicle_compatibility, :map)
      add :bc_fields, :map
      add :bc_submitted, :boolean, default: false
      add(:parent_sku, references(:products, type: :string, column: :sku))
    end

    create(index(:variation_products, [:title]))
    create(unique_index(:variation_products, [:sku]))
  end
end
