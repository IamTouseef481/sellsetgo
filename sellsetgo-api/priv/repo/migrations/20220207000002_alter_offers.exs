defmodule SellSetGoApi.Repo.Migrations.AlterOffers do
  use Ecto.Migration

  def change do
    alter table(:offers) do
      add :offer_id, :string
      add :country, :string
    end

    drop(unique_index(:offers, :user_id))
  end
end
