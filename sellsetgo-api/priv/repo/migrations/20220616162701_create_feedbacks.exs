defmodule SellSetGoApi.Repo.Migrations.CreateFeedbacks do
  use Ecto.Migration

  def change do
    create table(:feedbacks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :comment_text, :text
      add :item_title, :string
      add :item_id, :string
      add :commenting_user_id, :string
      add :commenting_user_score, :integer
      add :feedback_rating_star, :string
      add :price, :string
      add :currency_symbol, :string
      add :comment_time, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all, type: :string)

      timestamps()
    end

    create index(:feedbacks, [:user_id])
  end
end
