defmodule SellSetGoApi.Repo.Migrations.AddUniqueIndexToOffers do
  use Ecto.Migration

  def change do
    create(unique_index(:offers, [:offer_id, :user_id]))
  end
end
