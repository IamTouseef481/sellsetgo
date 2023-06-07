defmodule SellSetGoApiWeb.ImageView do
  use SellSetGoApiWeb, :view
  alias SellSetGoApiWeb.ImageView

  def render("images.json", %{images: images}) do
    %{data: render_many(images, ImageView, "image.json")}
  end

  def render("image.json", %{image: image}) do
    image
  end

  def render("index.json", %{data: result}) do
    %{
      data: %{
        image_urls: result.image_urls,
        total_entries: result.total_entries
      }
    }
  end
end
