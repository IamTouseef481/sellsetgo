defmodule SellSetGoApi.Repo.Migrations.AlterOfferAddSkuUserIndex do
  use Ecto.Migration

  def change do
    create unique_index(:offers, [:sku, :user_id])
  end
end
