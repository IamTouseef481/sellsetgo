defmodule SellSetGoApi.Repo.Migrations.AddMarketPlaceIdToOffers do
  use Ecto.Migration

  def change do
    alter table(:offers) do
      remove(:country)
      add(:marketplace_id, :string)
    end

    create(index(:offers, [:marketplace_id]))
  end
end
