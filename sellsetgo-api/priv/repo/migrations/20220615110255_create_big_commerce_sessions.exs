defmodule SellSetGoApi.Repo.Migrations.CreateBigCommerceSessions do
  use Ecto.Migration

  def change do
    create table(:big_commerce_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :access_token, :string
      add :other_params, :map
      add :user_id, references(:users, on_delete: :delete_all, type: :string)

      timestamps()
    end

    create index(:big_commerce_sessions, [:user_id])
  end
end
