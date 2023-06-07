defmodule SellSetGoApi.Repo.Migrations.CreateAdminEbaySiteDetails do
  use Ecto.Migration

  def change do
    create table(:admin_ebay_site_details, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, :integer
      add :global_id, :string
      add :language, :string
      add :territory, :string
      add :name, :string
      add :status, :string

      timestamps()
    end

    create unique_index(:admin_ebay_site_details, [:site_id, :global_id])
  end
end
