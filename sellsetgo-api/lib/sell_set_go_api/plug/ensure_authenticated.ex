defmodule SellSetGoApi.Plug.EnsureAuthenticated do
  @moduledoc false

  import Plug.Conn
  alias SellSetGoApi.Accounts.Sessions
  alias SellSetGoApi.{OauthEbay, Repo, Utils}
  alias OAuth2.{AccessToken, Client}

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :current_session) |> get_db_session() do
      {:error, :unauthenticated} ->
        unauthenticated(conn)

      {:ok, nil} ->
        unauthenticated(conn)

      {:ok, session} ->
        client = OauthEbay.session_to_client("User Access Token", Utils.get_host("auth"), session)

        if AccessToken.expired?(client.token) do
          Logger.debug("[STARTED] User Access Token refresh for session id #{session.id}")
          renew_session_token(conn, client, session)
        else
          conn |> assign(:current_session_record, session)
        end
    end
  end

  def get_db_session(nil), do: {:error, :unauthenticated}
  def get_db_session(id), do: Sessions.get_session(id)

  def renew_session_token(conn, client, session) do
    client =
      client
      |> Client.put_header("Accept", "application/json")
      |> Client.put_param(:grant_type, "refresh_token")
      |> Client.put_param(:scope, OauthEbay.client_scope())

    with {:ok, new_client} <- Client.refresh_token(client),
         {:ok, new_session} <-
           Sessions.update_session(session, %{
             "user_access_token_expires_at" =>
               new_client.token.expires_at |> DateTime.from_unix!(),
             "user_access_token" => new_client.token.access_token,
             "last_refreshed_at" => DateTime.utc_now()
           }) do
      conn |> assign(:current_session_record, new_session)
    else
      _error ->
        Task.async(fn ->
          Repo.delete!(session)
        end)

        conn
        |> configure_session(drop: true)
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{"error" => %{"details" => "unknown error occured. Please try again!"}})
        )
        |> halt()
    end
  end

  def unauthenticated(conn) do
    conn
    |> configure_session(drop: true)
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{"error" => %{"details" => "unauthenticated"}}))
    |> halt()
  end
end
