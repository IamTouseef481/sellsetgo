defmodule SellSetGoApi.Feedback do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "feedbacks" do
    field(:comment_text, :string)
    field(:item_title, :string)
    field(:item_id, :string)
    field(:commenting_user_id, :string)
    field(:commenting_user_score, :integer)
    field(:feedback_rating_star, :string)
    field(:price, :string)
    field(:currency_symbol, :string)
    field(:comment_time, :utc_datetime)
    belongs_to(:user, User)

    timestamps()
  end

  @required_fields [
    :comment_text,
    :item_title,
    :item_id,
    :commenting_user_id,
    :commenting_user_score,
    :feedback_rating_star,
    :price,
    :currency_symbol,
    :comment_time,
    :user_id
  ]
  @doc false
  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_length(:comment_text, max: 1000)
  end
end
