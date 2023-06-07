defmodule SellSetGoApiWeb.BigCommerceIntegrationView do
  use SellSetGoApiWeb, :view
  alias SellSetGoApiWeb.BigCommerceIntegrationView

  def render("index.json", %{sessions: sessions}) do
    %{data: render_many(sessions, BigCommerceIntegrationView, "session.json")}
  end

  def render("authorize.json", %{url: url}) do
    %{redirect_uri: url}
  end

  def render("show.json", %{data: data}) do
    %{data: data}
  end
end
