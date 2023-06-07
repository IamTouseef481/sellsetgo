defmodule SellSetGoApi.Repo.Migrations.AddSkuUserIdIndexesForProduct do
  use Ecto.Migration

  def up do
    create unique_index(:products, [:sku, :user_id])

    execute(
      "ALTER TABLE variation_products ADD CONSTRAINT parent_sku_user_id_fkey FOREIGN KEY(parent_sku, user_id) REFERENCES products(sku, user_id)"
    )

    execute(
      "ALTER TABLE variation_offers ADD CONSTRAINT parent_sku_user_id_fkey FOREIGN KEY(parent_sku, user_id) REFERENCES products(sku, user_id)"
    )

    create unique_index(:variation_products, [:sku, :user_id])
    execute "ALTER TABLE variation_products DROP CONSTRAINT variation_products_parent_sku_fkey"
    execute "ALTER TABLE variation_offers DROP CONSTRAINT variation_offers_parent_sku_fkey"
    drop_if_exists index(:products, [:sku])
    drop_if_exists index(:variation_products, [:sku])
  end

  def down do
    create_if_not_exists unique_index(:variation_products, [:sku])
    create_if_not_exists unique_index(:products, [:sku])

    execute "ALTER TABLE variation_offers ADD CONSTRAINT variation_offers_parent_sku_fkey FOREIGN KEY(parent_sku) REFERENCES products(sku)"

    execute "ALTER TABLE variation_products ADD CONSTRAINT variation_products_parent_sku_fkey FOREIGN KEY(parent_sku) REFERENCES products(sku)"

    drop_if_exists unique_index(:variation_products, [:sku, :user_id])
    execute("ALTER TABLE variation_offers drop CONSTRAINT parent_sku_user_id_fkey")
    execute("ALTER TABLE variation_products drop CONSTRAINT parent_sku_user_id_fkey")
    drop_if_exists unique_index(:products, [:sku, :user_id])
  end
end
