defmodule SellSetGoApiWeb.OfferView do
  use SellSetGoApiWeb, :view

  def render("offer.json", %{offer: offer}) do
    %{data: offer}
  end
end
