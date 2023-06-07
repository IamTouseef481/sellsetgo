defmodule SellSetGoApi.Repo.Migrations.AlterProductsAddBcFields do
  use Ecto.Migration

  def change do
    alter table("products") do
      add :bc_fields, :map
      add :bc_submitted, :boolean, default: false
    end
  end
end
