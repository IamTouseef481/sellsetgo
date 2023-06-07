defmodule SellSetGoApiWeb.BigCommerceIntegrationController do
  use SellSetGoApiWeb, :controller

  alias SellSetGoApi.Integrations
  alias SellSetGoApi.Oauth.BigCommerce

  action_fallback(SellSetGoApiWeb.FallbackController)

  def new(
        conn,
        %{
          "account_uuid" => _account_id,
          "code" => auth_code,
          "context" => context,
          "scope" => scope
        } = _params
      ) do
    with store_hash <- BigCommerce.get_store_hash(:context, context),
         bc_config <- Integrations.get_big_commerce_integration_using_store_hash(store_hash),
         {:ok, client} <-
           BigCommerce.get_client(context: context, scope: scope)
           |> BigCommerce.get_user_access_token(auth_code),
         {:ok, session_attrs} <-
           Integrations.construct_big_commerce_session_attrs(client.token, bc_config),
         {:ok, :success} <- Integrations.link_big_commerce(bc_config, session_attrs) do
      conn
      |> send_resp(200, "OK")
    else
      {:error, %OAuth2.Error{reason: :nxdomain}} ->
        {:error, %{key: :nxdomain, destination: "unable to reach big-commerce servers!"}}

      {:error, %OAuth2.Response{status_code: _code, body: body}} ->
        {:error, %{key: body["error"], description: body["error_description"]}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, params) do
    {:ok, data} =
      case Integrations.get_big_commerce_integration_by(user_id: user_id) do
        {:ok, result} ->
          {:ok, result}

        {:error, :not_found} ->
          Integrations.create_big_commerce_integration(params |> Map.put("user_id", user_id))
      end

    with {:ok, url} <- BigCommerce.get_authorize_url(store_url: data.store_url) do
      conn
      |> put_status(:created)
      |> render("authorize.json", url: url)
    end
  end

  def show(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, _params) do
    with {:ok, data} <- Integrations.get_big_commerce_integration_by(user_id: user_id) do
      conn
      |> put_status(:ok)
      |> render("show.json", data: data)
    end
  end

  def delete(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, _params) do
    with {:ok, data} <- Integrations.get_big_commerce_integration_by(user_id: user_id),
         {:ok, :success} <- Integrations.unlink_big_commerce(data) do
      conn
      |> send_resp(204, "")
    end
  end
end
