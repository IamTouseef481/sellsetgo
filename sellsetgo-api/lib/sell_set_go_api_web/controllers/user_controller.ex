defmodule SellSetGoApiWeb.UserController do
  use SellSetGoApiWeb, :controller

  alias EbayXmlApi.Store
  alias SellSetGoApi.Accounts.Users
  alias SellSetGoApi.{EbayXml, Feedbacks, OauthEbay, Reports, Utils}
  action_fallback(SellSetGoApiWeb.FallbackController)

  # def index(conn, _params) do
  #   users = Users.list_users()
  #   render(conn, "index.json", users: users)
  # end

  # def create(conn, %{"user" => user_params}) do
  #   with {:ok, %User{} = user} <- Users.create_user(user_params) do
  #     conn
  #     |> put_status(:created)
  #     |> put_resp_header("location", Routes.user_path(conn, :show, user))
  #     |> render("show.json", user: user)
  #   end
  # end

  # def show(conn, %{"id" => id}) do
  #   user = Users.get_user!(id)
  #   render(conn, "show.json", user: user)
  # end

  # def update(conn, %{"id" => id, "user" => user_params}) do
  #   user = Users.get_user!(id)

  #   with {:ok, %User{} = user} <- Users.update_user(user, user_params) do
  #     render(conn, "show.json", user: user)
  #   end
  # end

  # def delete(conn, %{"id" => id}) do
  #   user = Users.get_user!(id)

  #   with {:ok, %User{}} <- Users.delete_user(user) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end
  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "type" => "inventory_location",
          "inventory_location_params" =>
            %{"merchantLocationKey" => merchant_location_key} = inventory_location_params
        }
      ) do
    with route <-
           Utils.get_route("create_inventory_location", "EBAY") <> "/#{merchant_location_key}",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory", "EBAY"),
             current_session_record
           ),
         client <-
           OAuth2.Client.put_header(client, "content-type", "application/json"),
         {:ok, %OAuth2.Response{body: _body}} <-
           OAuth2.Client.post(client, route, inventory_location_params) do
      render(conn, "message.json", message: "location created successfully")
    end
  end

  def update(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "type" => "inventory_location",
          "inventory_location_params" =>
            %{"merchantLocationKey" => merchant_location_key} = inventory_location_params
        }
      ) do
    with route <-
           Utils.get_route("create_inventory_location", "EBAY") <>
             "/#{merchant_location_key}/update_location_details",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory", "EBAY"),
             current_session_record
           ),
         client <-
           OAuth2.Client.put_header(client, "content-type", "application/json"),
         {:ok, %OAuth2.Response{body: _body}} <-
           OAuth2.Client.post(client, route, inventory_location_params) do
      render(conn, "message.json", message: "location updated successfully")
    end
  end

  def delete(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "type" => "inventory_location",
          "inventory_location_params" => %{"merchantLocationKey" => merchant_location_key}
        }
      ) do
    with route <-
           Utils.get_route("create_inventory_location", "EBAY") <> "/#{merchant_location_key}",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory", "EBAY"),
             current_session_record
           ),
         client <-
           OAuth2.Client.put_header(client, "content-type", "application/json"),
         {:ok, %OAuth2.Response{body: _body}} <-
           OAuth2.Client.delete(client, route) do
      render(conn, "message.json", message: "location deleted successfully")
    end
  end

  def get_store_categories(
        %{assigns: %{current_session_record: %{user_access_token: uat, user_id: user_id}}} = conn,
        _params
      ) do
    processed_req_data = Store.get_store([])

    with {:ok, processed_req_hdrs} <-
           Utils.prep_headers(uat, processed_req_data),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         {:ok, resp_struct} <-
           Store.get_store_response(resp.body),
         {:ok, _store_categories} <-
           Users.insert_ebay_store_categories(resp_struct, user_id) do
      conn
      |> put_status(:created)
      |> render("message.json", message: "Store categories imported from eBay to SellSetGo")
    else
      {:error, response} -> {:error, response}
    end
  end

  def index(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "categories"}
      ) do
    conn
    |> render("store_categories.json",
      store_categories: Users.show_store_categories(user_id)
    )
  end

  def index(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "inventory_location"}
      ) do
    with route <- Utils.get_route("get_inventory_location", "EBAY") <> "?limit=100&offset=0",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory", "EBAY"),
             current_session_record
           ),
         {:ok, %OAuth2.Response{body: response}} <-
           OAuth2.Client.get(client, route) do
      locations = Users.form_inventory_locations(response)
      render(conn, "inventory_locations.json", inventory_locations: locations)
    else
      {:error, %OAuth2.Error{}} ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", message: "Invalid domain/credentials")
    end
  end

  def export_reports(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "offers"} = params
      ) do
    with {:ok, reports} <- Reports.get_offer_reports(params, user_id),
         {:ok, file_name} <-
           Reports.export_product_offer_reports(reports, "items", user_id) do
      conn
      |> render("message.json", message: file_name)
    end
  end

  def export_reports(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "product_offers"} = params
      ) do
    with {:ok, reports} <- Reports.get_product_offer_reports(params, user_id),
         {:ok, file_name} <- Reports.export_product_offer_reports(reports, "items", user_id) do
      conn
      |> render("message.json", message: file_name)
    end
  end

  def export_reports(
        %{assigns: %{current_session_record: %{user_id: user_id} = csr}} = conn,
        %{
          "type" => "item_specifics",
          "marketplace_id" => marketplace_id,
          "category_id" => category_id
        }
      ) do
    category_tree_id = Utils.get_site_id(marketplace_id)

    with route <-
           Utils.get_route("get_category_tree", "EBAY") <>
             "/#{category_tree_id}/get_item_aspects_for_category?category_id=#{category_id}",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("commerce_taxonomy", "EBAY"),
             csr
           ),
         {:ok, %OAuth2.Response{body: response}} <-
           OAuth2.Client.get(client, route),
         aspects <- Reports.get_all_aspects_for_category_id(response),
         {:ok, file_name} <-
           Reports.export_item_specifics_report(aspects, user_id, marketplace_id, category_id) do
      conn
      |> render("message.json", message: file_name)
    end
  end

  def download_reports(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"file_name" => file_name}
      ) do
    bucket_name = System.get_env("REPORTS_BUCKET", "dev-ebay-seller-reports")

    case ExAws.S3.get_object(bucket_name, "#{user_id}/#{file_name}")
         |> ExAws.request() do
      {:ok, %{body: data}} ->
        send_download(conn, {:binary, data}, filename: file_name)

      {:error, _reason} ->
        {:error, "AWS S3 error"}
    end
  end

  def list_reports(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, params) do
    with {:ok, reports} <- Reports.list_reports(params, user_id) do
      conn
      |> render("message.json", message: reports)
    end
  end

  def fetch_feedbacks(%{assigns: %{current_session_record: csr}} = conn, _params) do
    with {:ok, feedbacks} <- Feedbacks.store_feedback_in_db(csr) do
      render(conn, "message.json", message: feedbacks)
    end
  end

  def save_profile_details(%{assigns: %{current_session_record: %{user: user}}} = conn, params) do
    message =
      case Users.update_user(user, %{profile_details: params}) do
        {:ok, _} -> "Successfully added profile details"
        _ -> "Error while adding profile details"
      end

    render(conn, "message.json", message: message)
  end

  def update_profile_details(
        %{assigns: %{current_session_record: %{user: user}}} = conn,
        %{"name" => _, "email" => _, "mobile_number" => _} = params
      ) do
    message =
      case Users.update_user(user, %{profile_details: params}) do
        {:ok, _} -> "Successfully updated profile details"
        _ -> "Error while updating profile details"
      end

    render(conn, "message.json", message: message)
  end

  def get_profile_details(
        %{assigns: %{current_session_record: %{user: %{profile_details: profile_details}}}} =
          conn,
        _params
      ) do
    render(conn, "message.json",
      message: if(profile_details, do: Map.from_struct(profile_details), else: %{})
    )
  end
end
