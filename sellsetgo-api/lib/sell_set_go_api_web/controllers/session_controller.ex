defmodule SellSetGoApiWeb.SessionController do
  use SellSetGoApiWeb, :controller

  alias SellSetGoApi.Accounts.{Sessions, Users, UserSettings}
  alias SellSetGoApi.{EbayXml, OauthEbay, Repo, Utils}
  alias SellSetGoApiWeb.UserView
  action_fallback(SellSetGoApiWeb.FallbackController)

  def new(conn, %{"code" => auth_code, "expires_in" => _time} = _params) do
    host = Utils.get_host("commerce_identity", "EBAY")
    route = Utils.get_route("get_user", "EBAY")
    user_map_keys = Users.response_mapping()

    with {:ok, client} <- OauthEbay.get_client() |> OauthEbay.get_user_access_token(auth_code),
         new_client <- client |> Map.put(:site, host),
         {:ok, %OAuth2.Response{} = data} <- OAuth2.Client.get(new_client, route),
         processed_req_data <- EbayXmlApi.User.get_user([]),
         {:ok, processed_req_hdrs} <-
           Utils.prep_headers(client.token.access_token, processed_req_data),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         updated_response_body <-
           Map.put(data.body, "email", Users.extract_email_from_xml_api_response(resp.body)),
         {:ok, user_attrs} <- Utils.map_params(updated_response_body, user_map_keys),
         {:ok, session_attrs} <- Sessions.construct_session_attrs(new_client.token),
         new_user_attrs <- user_attrs |> Map.put("sessions", [session_attrs]),
         {:ok, %{id: user_id, sessions: sessions}} <- Users.create_user(new_user_attrs),
         {:ok, _} <- UserSettings.create_if_not_exists(user_id),
         {:ok, user} <- Users.get_user(user_id) do
      session_id = sessions |> List.first() |> Map.get(:id)

      conn
      |> configure_session(renew: true)
      |> put_session(:current_session, session_id)
      |> put_status(200)
      |> put_view(UserView)
      |> render("user.json", user: user)
    else
      {:error, %OAuth2.Error{reason: :nxdomain}} ->
        {:error, %{key: :nxdomain, destination: "unable to reach ebay servers!"}}

      {:error, %OAuth2.Response{status_code: _code, body: body}} ->
        {:error, %{key: body["error"], description: body["error_description"]}}
    end
  end

  def create(conn, _params) do
    with {:ok, url} <- OauthEbay.get_authorize_url() do
      conn
      |> put_status(200)
      |> render("authorize.json", url: url <> "&prompt=login")
    end
  end

  def show(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, "{\"data\": \"HELLO\"}")
  end

  def delete(conn, _params) do
    with _any_session <- Repo.delete!(conn.assigns[:current_session_record]) do
      conn
      |> configure_session(drop: true)
      |> put_resp_content_type("text/plain")
      |> send_resp(204, "")
      |> halt
    end
  end

  def invalid_route(conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{"error" => %{"details" => "Route not found"}}))
    |> halt()
  end
end
