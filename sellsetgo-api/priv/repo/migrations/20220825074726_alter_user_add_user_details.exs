defmodule SellSetGoApi.Repo.Migrations.AlterUserAddUserDetails do
  use Ecto.Migration

  def change do
    alter table("users") do
      add_if_not_exists(:profile_details, :map)
    end
  end
end
