defmodule SellSetGoApi.OauthEbay do
  @moduledoc false

  @app :sell_set_go_api

  require Logger
  require Protocol
  Protocol.derive(Jason.Encoder, OAuth2.Response, only: [:body])

  alias OAuth2.Client

  def scopes, do: Application.get_env(@app, :ebay_oauth2_scopes)
  def client_opts, do: Application.get_env(@app, :ebay_oauth2_client)
  def client_scope, do: scopes() |> Keyword.get(:scope)
  def client_ccg_scope, do: scopes() |> Keyword.get(:ccg_scope)
  def json_serializer, do: Application.get_env(:phoenix, :json_library)

  def get_client(opts \\ [])

  def get_client([]),
    do:
      Client.new(client_opts())
      |> Client.put_serializer("application/json", json_serializer())

  def get_client(opts),
    do:
      Client.new(opts)
      |> Client.put_serializer("application/json", json_serializer())

  def get_authorize_url(client_opts \\ [], client_scope \\ [])

  def get_authorize_url([], []),
    do: {:ok, Client.authorize_url!(get_client(), scope: client_scope())}

  def get_authorize_url([], client_scope),
    do: {:ok, Client.authorize_url!(get_client(), scope: client_scope)}

  def get_authorize_url(client_opts, []),
    do: {:ok, Client.authorize_url!(get_client(client_opts), scope: client_scope())}

  def get_authorize_url(client_opts, client_scope),
    do: {:ok, Client.authorize_url!(get_client(client_opts), scope: client_scope)}

  def get_user_access_token(client, authorization_code) do
    uat_stime = DateTime.utc_now()

    case client
         |> Client.put_header("accept", "application/json")
         |> Client.put_param(:code, authorization_code)
         |> Client.put_param(:grant_type, "authorization_code")
         |> Client.get_token() do
      {:ok, new_client} ->
        uat_etime = DateTime.utc_now()

        token =
          Map.get(new_client, :token)
          |> Map.put(:token_type, "Bearer")

        {_old, new_client_1} =
          new_client
          |> Map.get_and_update(:token, fn curr_val ->
            {curr_val, token}
          end)

        uat_time = DateTime.diff(uat_etime, uat_stime)
        Logger.info("User Access token got in #{uat_time} seconds")
        {:ok, new_client_1}

      error ->
        error
    end
  end

  def get_application_access_token do
    apt_stime = DateTime.utc_now()

    case client_opts()
         |> Keyword.put(:strategy, OAuth2.Strategy.ClientCredentials)
         |> get_client()
         |> Client.put_header("accept", "application/json")
         |> Client.put_param(:grant_type, "client_credentials")
         |> Client.put_param(:scope, client_ccg_scope())
         |> Client.get_token() do
      {:ok, new_client} ->
        apt_etime = DateTime.utc_now()

        token =
          Map.get(new_client, :token)
          |> Map.put(:token_type, "Bearer")

        {_old, new_client_1} =
          new_client
          |> Map.get_and_update(:token, fn curr_val ->
            {curr_val, token}
          end)

        apt_time = DateTime.diff(apt_etime, apt_stime)
        Logger.info("Application Access token got in #{apt_time} seconds")
        {:ok, new_client_1}

      error ->
        error
    end
  end

  def session_to_client(token_type \\ "User Access Token", site, session)

  def session_to_client(token_type, site, session) do
    client = get_client()

    token = %OAuth2.AccessToken{
      access_token: Map.get(session, :user_access_token),
      expires_at: Map.get(session, :user_access_token_expires_at) |> DateTime.to_unix(),
      refresh_token: Map.get(session, :refresh_token),
      token_type: token_type,
      other_params: %{
        "refresh_token_expires_in" =>
          DateTime.diff(Map.get(session, :refresh_token_expires_at), DateTime.utc_now())
      }
    }

    client |> Map.put(:token, token) |> Map.put(:site, site)
  end

  def get_client_by_session(token_type, session) do
    client = get_client()

    token = %OAuth2.AccessToken{
      access_token: Map.get(session, :user_access_token),
      expires_at: Map.get(session, :user_access_token_expires_at) |> DateTime.to_unix(),
      refresh_token: Map.get(session, :refresh_token),
      token_type: token_type,
      other_params: %{
        "refresh_token_expires_in" =>
          DateTime.diff(Map.get(session, :refresh_token_expires_at), DateTime.utc_now())
      }
    }

    client |> Map.put(:token, token)
  end

end
