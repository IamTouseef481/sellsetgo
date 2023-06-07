defmodule SellSetGoApiWeb.MiscView do
  use SellSetGoApiWeb, :view

  def render("index.json", %{data: data}) do
    %{
      data: %{
        feedback: data
      }
    }
  end
end
