defmodule SellSetGoApi.Repo.Migrations.UpdateGlobalTemplateTagUserIdIndex do
  use Ecto.Migration

  def change do
    execute("DROP INDEX global_template_tags_template_tags_user_id_index")
  end
end
