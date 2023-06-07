defmodule SellSetGoApi.Images do
  @moduledoc """
  The Listings context.
  """
  import Ecto.Query, warn: false
  alias SellSetGoApi.Listings.Image
  alias SellSetGoApi.Repo

  @doc """
  Returns the list of image users associate with user.

  ## Examples

  iex> list_image_urls("testUser", "1", "100")
      [%{}, ...]

  """
  def list_image_urls(user_id, page, page_limit) do
    offset = (String.to_integer(page) - 1) * String.to_integer(page_limit)

    Image
    |> select([u], %{id: u.id, s3_url: u.s3_url, provider_image_url: u.provider_image_url})
    |> where(user_id: ^user_id)
    |> order_by(asc: :inserted_at)
    |> offset(^offset)
    |> limit(^page_limit)
    |> Repo.all()
  end

  def get_images_count(user_id) do
    Image
    |> where(user_id: ^user_id)
    |> select(count())
    |> Repo.one()
  end
end
