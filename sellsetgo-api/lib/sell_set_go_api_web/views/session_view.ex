defmodule SellSetGoApiWeb.SessionView do
  use SellSetGoApiWeb, :view
  alias SellSetGoApiWeb.SessionView

  def render("index.json", %{sessions: sessions}) do
    %{data: render_many(sessions, SessionView, "session.json")}
  end

  def render("authorize.json", %{url: url}) do
    %{data: %{redirect_uri: url}}
  end

  def render("session.json", %{session: session}) do
    %{id: session.id}
  end
end
