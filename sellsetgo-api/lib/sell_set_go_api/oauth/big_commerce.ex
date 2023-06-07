defmodule SellSetGoApi.Oauth.BigCommerce do
  @moduledoc false

  @app :sell_set_go_api
  @store_hash_regex ~r/https\:\/\/store\-(?<store_hash>.*)\.mybigcommerce\.com.*$/
  @context_store_hash_regex ~r/stores?\/(?<store_hash>.*$)/

  require Logger

  alias OAuth2.Client

  def scopes, do: Application.get_env(@app, :big_commerce_oauth2_scopes)
  def client_opts, do: Application.get_env(@app, :big_commerce_oauth2_client)
  def client_scope, do: scopes() |> Keyword.get(:scope)
  def json_serializer, do: Application.get_env(:phoenix, :json_library)

  def get_store_hash(store_url) do
    Regex.named_captures(@store_hash_regex, store_url)
    |> Map.get("store_hash")
  end

  def get_store_hash(:context, context) do
    Regex.named_captures(@context_store_hash_regex, context)
    |> Map.get("store_hash")
  end

  def get_client(opts \\ [])

  def get_client([]),
    do:
      Client.new(client_opts())
      |> Client.put_serializer("application/json", json_serializer())

  def get_client(store_url: store_url),
    do:
      get_client([])
      |> Client.put_param("context", "stores/#{get_store_hash(store_url)}")

  def get_client(opts),
    do:
      get_client([])
      |> Client.put_param("client_secret", client_opts()[:client_secret])
      |> Client.merge_params(opts)

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

  def session_to_client(token_type \\ "", site \\ "https://api.bigcommerce.com", session)

  def session_to_client(token_type, site, session) do
    client = get_client()
    access_token = Map.get(session, :access_token)
    other_params = Map.get(session, :other_params)
    context = Map.get(other_params, "context")
    store_hash = get_store_hash(:context, context)

    token = %OAuth2.AccessToken{
      access_token: access_token,
      token_type: token_type,
      other_params: other_params
    }

    client
    |> Map.put(:big_commerce_token, token)
    |> Map.put(:site, site)
    |> Map.put(:store_hash, store_hash)
    |> Client.merge_params(other_params)
    |> Client.put_header("X-Auth-Token", access_token)
    |> Client.put_header("X-Auth-Client", client.client_id)
    |> Client.put_header("Content-Type", "application/json")
  end
end
