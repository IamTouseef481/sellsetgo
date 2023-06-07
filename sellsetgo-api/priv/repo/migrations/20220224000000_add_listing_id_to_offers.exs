defmodule SellSetGoApi.Repo.Migrations.AddListingIdToOffers do
  use Ecto.Migration

  def change do
    alter table(:offers) do
      add(:listing_id, :string)
    end

    create(index(:offers, [:listing_id]))
  end
end
