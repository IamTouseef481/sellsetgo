defmodule SellSetGoApiWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use SellSetGoApiWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(SellSetGoApiWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(SellSetGoApiWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, %OAuth2.Response{body: %{"errors" => [details]}, status_code: status_code}}) do
    conn
    |> put_status(status_code)
    |> put_view(SellSetGoApiWeb.ErrorView)
    |> render("ebay_error.json", details: details)
  end

  def call(conn, {:error, message}) do
    conn
    |> put_status(:bad_request)
    |> put_view(SellSetGoApiWeb.ErrorView)
    |> render("400.json", %{message: message})
  end

  def call(conn, {:error, status, message}) do
    conn
    |> put_status(status)
    |> put_view(SellSetGoApiWeb.ErrorView)
    |> render("error.json", %{message: message})
  end
end
