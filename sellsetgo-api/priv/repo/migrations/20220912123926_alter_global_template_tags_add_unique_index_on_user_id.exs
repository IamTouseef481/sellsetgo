defmodule SellSetGoApi.Repo.Migrations.AlterGlobalTemplateTagsAddUniqueIndexOnUserId do
  use Ecto.Migration

  def change do
    create(unique_index(:global_template_tags, [:user_id]))
  end
end
