defmodule SellSetGoApi.Repo.Migrations.CreateDescriptionTemplates do
  use Ecto.Migration

  def change do
    create table(:description_templates, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string)
      add(:template, :string)
      add(:user_id, references("users", on_delete: :delete_all, type: :string))

      timestamps()
    end

    create(unique_index(:description_templates, [:user_id]))
  end
end
