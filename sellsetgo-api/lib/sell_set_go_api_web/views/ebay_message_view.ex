defmodule SellSetGoApiWeb.EbayMessageView do
  use SellSetGoApiWeb, :view

  def render("index.json", %{result: result}) do
    %{
      data: result
    }
  end
end
