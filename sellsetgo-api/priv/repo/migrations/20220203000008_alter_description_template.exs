defmodule SellSetGoApi.Repo.Migrations.AlterDescriptionTemplates do
  use Ecto.Migration

  def change do
    alter table(:description_templates) do
      modify :template, :text
    end

    drop(unique_index(:description_templates, :user_id))
    create(unique_index(:description_templates, [:name, :user_id]))
  end
end
