defmodule SellSetGoApi.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:s3_url, :string, null: false)
      add(:order, :integer, null: false, default: 999)
      add(:provider, :string, null: false)
      add(:provider_image_url, :string)
      add(:user_id, references(:users, on_delete: :delete_all, type: :string))

      timestamps()
    end

    create(index(:images, [:user_id]))
  end
end
