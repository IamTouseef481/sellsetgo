defmodule SellSetGoApi.Repo.Migrations.CreateAdminRoutes do
  use Ecto.Migration

  def change do
    create table(:admin_routes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string
      add :name, :string
      add :url, :string

      timestamps()
    end

    create unique_index(:admin_routes, [:provider, :name])
    create index(:admin_routes, [:name])
  end
end
