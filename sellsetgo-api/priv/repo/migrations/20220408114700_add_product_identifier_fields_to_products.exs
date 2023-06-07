defmodule SellSetGoApi.Repo.Migrations.AddProductIdentifierFieldsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add(:ean, {:array, :string})
      add(:isbn, {:array, :string})
      add(:mpn, :string)
      add(:upc, {:array, :string})
    end
  end
end
