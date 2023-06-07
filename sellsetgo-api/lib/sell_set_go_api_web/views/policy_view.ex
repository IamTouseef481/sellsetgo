defmodule SellSetGoApiWeb.PolicyView do
  use SellSetGoApiWeb, :view

  def render("policy_index.json", %{policy_lists: policy_lists}) do
    %{data: policy_lists}
  end
end
