defmodule SellSetGoApi.Repo.Migrations.CreateBigcommerceIntegrations do
  use Ecto.Migration

  def change do
    create table(:big_commerce_integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :store_url, :string, null: false
      add :active, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :string), null: false

      timestamps()
    end

    create index(:big_commerce_integrations, [:user_id])
    create unique_index(:big_commerce_integrations, [:user_id, :store_url])
  end
end
