defmodule SellSetGoApi.Repo.Migrations.AddVehicleCompatibilityToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add(:vehicle_compatibility, :map)
    end
  end
end
