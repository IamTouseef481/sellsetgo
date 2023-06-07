defmodule SellSetGoApiWeb.ConfigurationView do
  use SellSetGoApiWeb, :view

  def render("tags.json", %{tags: tags}) do
    %{data: tags}
  end
end
