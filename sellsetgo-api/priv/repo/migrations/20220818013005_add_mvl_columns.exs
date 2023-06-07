defmodule SellSetGoApi.Repo.Migrations.AddMvlColumns do
  use Ecto.Migration

  def change do
    alter table("products") do
      add :variant_skus, {:array, :string}
      add :aspects_image_varies_by, {:array, :string}
      add :specifications, {:array, :map}
    end
  end
end
