defmodule SellSetGoApi.Repo.Migrations.AlterVariationProductRenamePackageSpec do
  use Ecto.Migration

  def change do
    rename table(:variation_products), :package_specs, to: :package_weight_and_size
  end
end
