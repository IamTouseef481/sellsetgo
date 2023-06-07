defmodule SellSetGoApiWeb.ImageController do
  use SellSetGoApiWeb, :controller

  alias SellSetGoApi.{Listings, Images}
  alias SellSetGoApi.Listings.Image

  action_fallback(SellSetGoApiWeb.FallbackController)

  def index(conn, %{"page" => page, "page_limit" => page_limit}) do
    user_id = SellSetGoApi.get_user_id(conn)
    image_urls = Images.list_image_urls(user_id, page, page_limit)
    total_entries = Images.get_images_count(user_id)

    result = %{}
      |> Map.put(:image_urls, image_urls)
      |> Map.put(:total_entries, total_entries)

    render(conn, "index.json", data: result)
  end

  def create(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, %{
        "images" => image_params
      }) do
    case Listings.create_image(user_id, image_params) do
      {:ok, images} ->
        conn
        |> put_status(:created)
        |> render("images.json", images: images)

      error ->
        error
    end
  end

  # def show(conn, %{"id" => id}) do
  #   image = Listings.get_image!(id)
  #   render(conn, "show.json", image: image)
  # end

  # def update(conn, %{"id" => id, "image" => image_params}) do
  #   image = Listings.get_image!(id)

  #   with {:ok, %Image{} = image} <- Listings.update_image(image, image_params) do
  #     render(conn, "show.json", image: image)
  #   end
  # end

  def delete(conn, %{"id" => id}) do
    image = Listings.get_image!(id)

    with {:ok, %Image{}} <- Listings.delete_image(image) do
      send_resp(conn, :no_content, "")
    end
  end
end
