defmodule SellSetGoApi.Repo.Migrations.AlterProductChangePackageSpecsName do
  use Ecto.Migration

  def change do
    rename table(:products), :package_specs, to: :package_weight_and_size
  end
end
