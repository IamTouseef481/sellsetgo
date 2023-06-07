defmodule SellSetGoApiWeb.EbayCommonController do
  @moduledoc """
    This module contains the common functions to process EBAY.
  """
  use SellSetGoApiWeb, :controller
  alias Plug.Conn.Query
  alias SellSetGoApi.{Admin, Dashboards, Listings, OauthEbay, Utils}

  action_fallback(SellSetGoApiWeb.FallbackController)

  def index(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, %{
        "resource_name" => "getEbayCategoryIDs",
        "marketplace_id" => marketplace_id
      }) do
    with categories <- Listings.get_all_categories_for_user(user_id, marketplace_id) do
      render(conn, "index.json", result: categories)
    end
  end

  def index(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "resource_name" => "parts_compatibility",
          "marketplace_id" => marketplace_id
        } = params
      ) do
    category_tree_id = Utils.get_site_id(marketplace_id)
    host = Utils.get_host("commerce_taxonomy")

    route =
      (Utils.get_route("parts_compatibility")
       |> String.replace("{category_tree_id}", "#{category_tree_id}")) <>
        "#{URI.encode(params["filter"])}"

    client =
      OauthEbay.session_to_client("Bearer", host, current_session_record)
      |> OAuth2.Client.put_header("content-type", "application/json")

    with {:ok, %OAuth2.Response{body: result}} <- OAuth2.Client.get(client, route) do
      render(conn, "index.json", result: result)
    end
  end

  def index(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "resource_name" => resource_name,
          "marketplace_id" => marketplace_id
        } = params
      ) do
    category_tree_id = Utils.get_site_id(marketplace_id)

    route =
      case params do
        %{"category_id" => category_id} ->
          (Utils.get_route(resource_name) <> "?category_id=#{category_id}")
          |> String.replace("category_tree_id", "#{category_tree_id}")

        %{"q" => q_string} ->
          q_string = Query.encode(q_string)

          (Utils.get_route(resource_name) <> "?q=#{q_string}")
          |> String.replace("category_tree_id", "#{category_tree_id}")
      end

    with client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("commerce_taxonomy"),
             current_session_record
           ),
         {:ok, %OAuth2.Response{body: result}} <- OAuth2.Client.get(client, route) do
      conn
      |> render("index.json", result: result)
    end
  end

  def index(conn, %{"type" => "categories", "marketplace_id" => marketplace_id}) do
    conn
    |> render("admin_categories.json",
      admin_categories: Admin.show_admin_categories(marketplace_id)
    )
  end

  def opt_in(%{assigns: %{current_session_record: current_session_record}} = conn, %{
        "program_type" => program_type,
        "marketplaceId" => marketplace_id
      }) do
    with route <- Utils.get_route("opt_in"),
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("sell", "EBAY"),
             current_session_record
           ),
         client <-
           OAuth2.Client.put_header(client, "content-type", "application/json"),
         client <-
           OAuth2.Client.put_header(
             client,
             "content-language",
             Utils.get_content_language(marketplace_id)
           ),
         {:ok, %OAuth2.Response{status_code: 200}} <-
           OAuth2.Client.post(client, route, %{programType: program_type}) do
      conn
      |> put_status(200)
      |> render("message.json", message: "Opted in successful for #{program_type}")
    end
  end

  def opted_in(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"marketplaceId" => _marketplace_id}
      ) do
    with route <- Utils.get_route("opted_in"),
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("sell", "EBAY"),
             current_session_record
           ),
         {:ok, %OAuth2.Response{body: result}} <- OAuth2.Client.get(client, route) do
      conn
      |> put_status(200)
      |> render("index.json", %{result: result})
    end
  end

  def dashboard(
        %{assigns: %{current_session_record: csr}} = conn,
        %{"marketplace_id" => marketplace_id}
      ) do
    with {:ok, dashboard} <- Dashboards.get_dashboard_details(marketplace_id, csr) do
      conn
      |> render("index.json", %{
        result: dashboard
      })
    end
  end

  def translate(%{assigns: %{current_session_record: current_session_record}} = conn, params) do
    route = Utils.get_route("translate")

    client =
      OauthEbay.session_to_client(
        "Bearer",
        Utils.get_host("commerce_translation", "EBAY"),
        current_session_record
      )
      |> OAuth2.Client.put_header("content-type", "application/json")

    with {:ok, %OAuth2.Response{body: result}} <- OAuth2.Client.post(client, route, params) do
      conn
      |> put_status(200)
      |> render("index.json", %{result: result})
    end
  end
end
