defmodule SellSetGoApi.Repo.Migrations.CreateOffers do
  use Ecto.Migration

  def change do
    create table(:offers, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:last_verified_at, :string)
      add(:listing_fees, :map)
      add(:offer_detail, :map)
      add(:published_at, :string)
      add(:revised_at, :string)
      add(:status, :string)
      add(:user_id, references("users", on_delete: :delete_all, type: :string))

      timestamps()
    end

    create(unique_index(:offers, [:user_id]))
    create(index(:offers, [:status]))
  end
end
