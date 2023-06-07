defmodule SellSetGoApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      # UserId
      add(:id, :string, primary_key: true)
      add(:username, :string, null: false)
      add(:account_type, :string, null: false)
      add(:site, :string, null: false)
      add(:provider, :string, null: false)
      timestamps()
    end

    create(index(:users, [:username]))
    create(index(:users, [:account_type]))
    create(index(:users, [:site]))
  end
end
