defmodule SellSetGoApi.Repo.Migrations.AddSkuToImage do
  use Ecto.Migration

  def change do
    alter table(:images) do
      add(:sku, :string)
    end

    create(index(:images, [:sku]))
  end
end
