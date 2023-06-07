defmodule SellSetGoApi.Repo.Migrations.Orders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:order_id, :string)
      add(:creation_date, :utc_datetime)
      add(:last_modified_date, :utc_datetime)
      add(:order_fulfillment_status, :string)
      add(:order_payment_status, :string)
      add(:seller_id, :string)
      add(:buyer, :map)
      add(:pricing_summary, :map)
      add(:payments, :map)
      add(:fulfillment_instructions, {:array, :map})
      add(:line_items, {:array, :map})
      add(:sales_record_ref, :string)
      add(:tracking_details, {:array, :map})
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))
      timestamps()
    end

    create(index(:orders, [:user_id]))
    create(unique_index(:orders, [:user_id, :order_id]))
    rename table("message_fetch_times"), to: table("last_fetch_times")

    alter table(:last_fetch_times) do
      add(:type, :string, default: "message")
    end

    drop(unique_index(:message_fetch_times, [:user_id]))
    create(unique_index(:last_fetch_times, [:user_id, :type]))
  end
end
