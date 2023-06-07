defmodule SellSetGoApi.Repo.Migrations.CreateTableVariationOffers do
  use Ecto.Migration

  def change do
    create table(:variation_offers, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:last_verified_at, :string)
      add(:offer_detail, :map)
      add(:published_at, :string)
      add(:revised_at, :string)
      add(:status, :string)
      add(:user_id, references("users", on_delete: :delete_all, type: :string))
      timestamps()
      add(:offer_id, :string)
      add(:sku, :string)
      add(:listing_id, :string)
      add(:marketplace_id, :string)
      add(:is_submitted, :boolean)
      add(:bc_product_id, :integer)
      add(:parent_sku, references(:products, type: :string, column: :sku))
    end

    create(index(:variation_offers, [:status]))
    create(index(:variation_offers, [:listing_id]))
    create(index(:variation_offers, [:marketplace_id]))
    create unique_index(:variation_offers, [:sku, :user_id])
  end
end
