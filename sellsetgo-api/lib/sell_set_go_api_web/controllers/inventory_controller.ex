defmodule SellSetGoApiWeb.InventoryController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.Inventory.{Data, Products}
  alias SellSetGoApi.Offers.Offers
  alias SellSetGoApi.{Listings, OauthEbay, Utils}

  alias SellSetGoApi.BigCommerceIntegrations

  action_fallback(SellSetGoApiWeb.FallbackController)

  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "draft"} = params
      ) do
    params = Map.put(params, "user_id", current_session_record.user_id)

    with {:ok, %{create_product: %{images: images, image_ids: image_ids}}} <-
           Products.create_product_and_offer(params, current_session_record) do
      set_images_order(images, image_ids)

      conn
      |> render("message.json", message: "Inventory item drafted")
    end
  end

  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "submit", "sku" => sku, "marketplaceId" => marketplace_id} = params
      ) do
    params = Map.put(params, "user_id", current_session_record.user_id)

    with {:ok, %{create_product: %{images: images, image_ids: image_ids} = product}} <-
           Products.create_product_and_offer(params, current_session_record),
         _ <- set_images_order(images, image_ids),
         {:ok, _images} <-
           Listings.update_provider_image_url(product.image_ids, current_session_record, sku),
         {:ok, %OAuth2.Response{body: _body}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory_item", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.put(
             Utils.get_route("inventory_item", "EBAY") <>
               "/#{sku |> URI.encode(&URI.char_unreserved?/1)}",
             Data.stitch_inventory_item(params),
             [
               {"content-type", "application/json"},
               {"content-language", Utils.get_content_language(marketplace_id)}
             ]
           ),
         {:ok, _} <- BigCommerceIntegrations.create(params),
         {:ok, _product} <- Products.update_product(product, %{"is_submitted" => true}) do
      conn
      |> render("message.json", message: "Inventory item submitted successfully")
    else
      {:error, %OAuth2.Error{}} ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", message: "Invalid domain/credentials")

      error ->
        error
    end
  end

  def delete(%{assigns: %{current_session_record: current_session_record}} = conn, %{"sku" => sku}) do
    with {:ok, _msg} <- BigCommerceIntegrations.delete(current_session_record, sku),
         {:ok, %{is_submitted: true} = _product} <-
           Products.update_product_by_sku(sku, %{"status" => "ended"}, current_session_record),
         {:ok, _offer} <-
           Offers.update_offer_by_sku(sku, %{"status" => "ended"}, current_session_record),
         host <- Utils.get_host("inventory_item", "EBAY"),
         route <-
           Utils.get_route("inventory_item", "EBAY") <>
             "/#{sku |> URI.encode(&URI.char_unreserved?/1)}",
         {_status, %OAuth2.Response{body: _body, status_code: 204}} <-
           OauthEbay.session_to_client("Bearer", host, current_session_record)
           |> OAuth2.Client.delete(route, [], [{"content-type", "application/json"}]) do
      render(conn, "message.json", message: "Inventory item deleted")
    else
      {:error, %OAuth2.Response{body: _body, status_code: _status_code}} ->
        render(conn, "message.json", message: "Error while updating on ebay")

      {:ok, _resp} ->
        render(conn, "message.json", message: "Inventory item deleted")

      _error ->
        render(conn, "message.json", message: "Error while updating from SSG")
    end
  end

  def show(%{assigns: %{current_session_record: csr}} = conn, %{"sku" => sku}) do
    case Products.get_product_by_sku(sku, csr) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render("message.json", message: "Inventory item not found")

      product ->
        conn
        |> put_status(200)
        |> render("product.json", product: product)
    end
  end

  def update_price_and_quantity(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"requests" => req} = params
      ) do
    with :ok <- Products.update_price_and_quantity(req, current_session_record),
         {:ok, %OAuth2.Response{body: response}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory_item", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.post(
             Utils.get_route("bulk_update_price_quantity", "EBAY"),
             params,
             [
               {"content-type", "application/json"}
             ]
           ) do
      conn
      |> render("message.json", message: response)
    end
  end

  def my_ebay_selling(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        params
      ) do
    with {:ok, item} <-
           Listings.my_ebay_selling(current_session_record, params) do
      conn
      |> put_status(200)
      |> render("product.json", product: item)
    end
  end

  def update_sku(%{assigns: %{current_session_record: current_session_record}} = conn, params) do
    with {:ok, response} <- Listings.update_sku(current_session_record, params) do
      conn
      |> put_status(200)
      |> render("product.json", product: response)
    end
  end

  # def sku_validation(
  #       %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
  #       %{"sku" => sku}
  #     ) do
  #   message = Listings.sku_validation(user_id, sku)

  #   conn
  #   |> render("message.json", message: message)
  # end

  def sku_validation(conn, %{"sku" => sku}) do
    conn
    |> render("message.json", message: Listings.sku_validation(sku))
  end

  def grid_collection(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        params
      ) do
    with {:ok, grid_collections, total_entries, total_pages} <-
           Listings.grid_collection(current_session_record, params) do
      conn
      |> render("grid_collection.json",
        product: grid_collections,
        total_entries: total_entries,
        total_pages: total_pages
      )
    end
  end

  def migration(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"marketplaceId" => marketplace_id, "requests" => listing_ids}
      ) do
    with resp <-
           Listings.migration(current_session_record, marketplace_id, listing_ids, "migration"),
         {:ok, result} <- transform_migration_resp(resp, listing_ids),
         {:ok, _} <- Listings.migrate_product_and_offer(result, current_session_record) do
      conn
      |> render("product.json", product: result)
    else
      {:error, _} = resp -> resp
      _ -> {:error, "Error while migrating from eBay"}
    end
  end

  defp transform_migration_resp(resp, listing_ids) do
    case resp do
      {:error,
       %OAuth2.Response{
         body: %{
           "responses" => [%{"statusCode" => 409, "errors" => [%{"errorId" => 25002} | _]} | _]
         }
       }} ->
        sku = hd(listing_ids)["sku"]

        if sku do
          {:ok,
           %{
             "responses" => [%{"inventoryItems" => [%{"sku" => sku}]}]
           }}
        else
          {:error, "Item Already migrated, SKU to be provided in API to migrate item to SSG"}
        end

      _ ->
        resp
    end
  end

  def bulk_update_qty_price(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"csv" => csv, "marketplaceId" => marketplace_id}
      ) do
    {_skus_in_db, skus_not_in_db} = Listings.process_csv(current_session_record, csv)

    processed_list = Listings.revising_price(current_session_record, marketplace_id)

    list = skus_not_in_db ++ List.flatten(processed_list)

    with {:ok, file_name} <- Listings.create_csv_error_file(list, current_session_record) do
      conn
      |> render("message.json", message: file_name)
    end
  end

  def bulk_update(
        %{assigns: %{current_session_record: csr}} = conn,
        %{"replace_field" => "quantity"} = params
      ) do
    result = Products.bulk_update_quantity(csr, params)

    conn
    |> render("product.json", product: result)
  end

  def bulk_update(
        %{assigns: %{current_session_record: csr}} = conn,
        %{"replace_field" => "description_template"} = params
      ) do
    result = Offers.bulk_update_description_template(csr, params)

    conn
    |> render("product.json", product: result)
  end

  def bulk_update(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"csv" => csv, "marketplace_id" => marketplace_id}
      ) do
    with {:ok, file_name} <-
           Products.process_update_csv(current_session_record, csv, marketplace_id) do
      render(conn, "message.json", message: file_name)
    end
  end

  def create_product_compatibility(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"marketplace_id" => marketplace_id, "sku" => sku, "compatibility" => compatibility}
      ) do
    host = Utils.get_host("inventory_item")

    route =
      Utils.get_route("inventory_item", "EBAY") <>
        "/#{sku |> URI.encode(&URI.char_unreserved?/1)}/product_compatibility"

    lang = Utils.get_content_language(marketplace_id)

    client =
      OauthEbay.session_to_client("Bearer", host, current_session_record)
      |> OAuth2.Client.put_header("content-type", "application/json")
      |> OAuth2.Client.put_header("content-language", lang)

    with {:ok, %OAuth2.Response{body: "", status_code: 201}} <-
           OAuth2.Client.put(client, route, compatibility, [], recv_timeout: 30_000),
         {:ok, %{vehicle_compatibility: vehicle_compatibility}} <-
           Products.update_product_by_sku(
             sku,
             %{vehicle_compatibility: compatibility},
             current_session_record
           ) do
      render(conn, "message.json", message: vehicle_compatibility)
    else
      {:ok, %OAuth2.Response{body: %{"warnings" => warnings}}} ->
        {:error, warnings}

      {:error, %OAuth2.Response{body: body}} ->
        {:error, body}
    end
  end

  def delete_product_compatibility(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"marketplace_id" => marketplace_id, "sku" => sku}
      ) do
    host = Utils.get_host("inventory_item")

    route =
      Utils.get_route("inventory_item", "EBAY") <>
        "/#{sku |> URI.encode(&URI.char_unreserved?/1)}/product_compatibility"

    lang = Utils.get_content_language(marketplace_id)

    client =
      OauthEbay.session_to_client("Bearer", host, current_session_record)
      |> OAuth2.Client.put_header("content-type", "application/json")
      |> OAuth2.Client.put_header("content-language", lang)

    with {:ok, %OAuth2.Response{body: ""}} <-
           OAuth2.Client.delete(client, route),
         {:ok, %{vehicle_compatibility: vehicle_compatibility}} <-
           Products.update_product_by_sku(
             sku,
             %{vehicle_compatibility: %{}},
             current_session_record
           ) do
      render(conn, "message.json", message: vehicle_compatibility)
    end
  end

  def get_product_compatibility(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"sku" => sku}
      ) do
    with {:ok, product_compatibility} <-
           Products.get_product_compatibility(user_id, sku) do
      render(conn, "product.json", product: product_compatibility)
    end
  end

  def update_big_commerce_inventory(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        params
      ) do
    params = Map.put(params, "user_id", current_session_record.user_id)

    msg =
      case BigCommerceIntegrations.update(params) do
        {:ok, :updated_successfully} ->
          "Successfully updated the BigCommerce Inventory."

        {:error, _} ->
          "Failed to updated the BigCommerce Inventory."
      end

    render(conn, "message.json", message: msg)
  end

  defp set_images_order(_, []), do: nil

  defp set_images_order(images, image_ids) do
    Enum.map(images, fn x ->
      Map.put(x, :order, Enum.find_index(image_ids, &(&1 == x.id)) || 999)
    end)
    |> Products.update_product_image_order()
  end

  def bulk_create_from_csv(
        %{assigns: %{current_session_record: csr}} = conn,
        %{"csv" => csv}
      ) do
    with {:ok, csv_data} <- Listings.read_csv_for_bulk_create(csv),
         {:ok, data, image_params} <- Listings.csv_validation(csv_data, csr),
         #         {:ok, _} <- Listings.create_bulk_images(image_params),
         {:ok, _} <-
           Listings.create_bulk_product_and_offer(Enum.group_by(data, & &1["producttype"]), csr),
         {:ok, file_name} <- Listings.bulk_create_csv_resp(data, csv, csr, "Success") do
      Task.async(fn -> Listings.update_s3_url(image_params, csr) end)

      conn
      |> render("message.json", message: file_name)
    else
      {:error, data} ->
        {:ok, file_name} = Listings.bulk_create_csv_resp(data, csv, csr, "Failed")
        render(conn, "message.json", message: file_name)

      error ->
        error
    end
  end
end
