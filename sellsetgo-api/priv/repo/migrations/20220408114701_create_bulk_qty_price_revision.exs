defmodule SellSetGoApi.Repo.Migrations.CreateBulkQtyPriceRevision do
  use Ecto.Migration

  def change do
    create table(:bulk_qty_price_revisions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:item_id, :string)
      add(:sku, :string)
      add(:price, :string)
      add(:warehouse_qty, :string)
      add(:ebay_qty, :string)
      add(:status, :string)
      add(:offer_id, :string)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      timestamps()
    end

    create(index(:bulk_qty_price_revisions, [:user_id, :status]))
    create(unique_index(:bulk_qty_price_revisions, [:sku, :offer_id]))
  end
end
