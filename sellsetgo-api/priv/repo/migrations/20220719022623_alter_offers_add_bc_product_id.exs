defmodule SellSetGoApi.Repo.Migrations.AlterOffersAddBcProductId do
  use Ecto.Migration

  def change do
    alter table("offers") do
      add :bc_product_id, :integer
    end
  end
end
