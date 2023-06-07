defmodule SellSetGoApi.Repo.Migrations.AddIndexToProfileDetails do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX IF NOT EXISTS users_profile_details ON users USING GIN(profile_details)")
  end

  def down do
    execute("DROP INDEX users_profile_details")
  end
end
