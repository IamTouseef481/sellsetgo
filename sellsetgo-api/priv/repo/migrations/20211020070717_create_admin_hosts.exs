defmodule SellSetGoApi.Repo.Migrations.CreateAdminHosts do
  use Ecto.Migration

  def change do
    create table(:admin_hosts, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:provider, :string)
      add(:name, :string)
      add(:prod_host, :string)
      add(:sandbox_host, :string)

      timestamps()
    end

    create(unique_index(:admin_hosts, [:provider, :name]))
    create(index(:admin_hosts, [:name]))
  end
end
