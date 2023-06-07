defmodule SellSetGoApi.Repo.Migrations.AddCurrencyToEbayDetails do
  use Ecto.Migration

  def change do
    alter table(:admin_ebay_site_details) do
      add :currency, :string
    end
  end
end
