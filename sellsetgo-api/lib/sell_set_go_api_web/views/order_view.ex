defmodule SellSetGoApiWeb.OrderView do
  use SellSetGoApiWeb, :view

  def render("order.json", %{order: order}) do
    %{data: order}
  end
end
