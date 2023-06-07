defmodule SellSetGoApi.Repo.Migrations.AddIsSubmittedToOffersAndProducts do
  use Ecto.Migration

  def change do
    alter table(:offers) do
      add(:is_submitted, :boolean)
    end

    alter table(:products) do
      add(:is_submitted, :boolean)
    end
  end
end
