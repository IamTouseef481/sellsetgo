defmodule SellSetGoApi.Repo.Migrations.CreateGlobalTemplateTags do
  use Ecto.Migration

  def change do
    create table(:global_template_tags, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:template_tags, {:array, :map}, default: [])
      add(:user_id, references("users", on_delete: :delete_all, type: :string))

      timestamps()
    end

    create(unique_index(:global_template_tags, [:template_tags, :user_id]))
  end
end
