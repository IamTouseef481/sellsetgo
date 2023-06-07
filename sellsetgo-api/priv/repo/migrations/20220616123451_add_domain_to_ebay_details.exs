defmodule SellSetGoApi.Repo.Migrations.AddDomainToEbayDetails do
  use Ecto.Migration

  def change do
    alter table(:admin_ebay_site_details) do
      add :domain, :string
      add :currency_symbol, :string
    end
  end
end
