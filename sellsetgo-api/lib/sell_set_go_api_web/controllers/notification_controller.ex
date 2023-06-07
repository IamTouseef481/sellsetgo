defmodule SellSetGoApiWeb.NotificationController do
  use SellSetGoApiWeb, :controller
  alias EbayXmlApi.Notification
  alias SellSetGoApi.{EbayXml, Utils}
  alias SellSetGoApi.Inventory.{VariationProducts, Products}
  alias SellSetGoApi.Accounts.UserSettings

  action_fallback(SellSetGoApiWeb.FallbackController)

  def subscribe(%{assigns: %{current_session_record: csr}} = conn, %{"event_type" => event_names}) do
    try do
      processed_req_data = Notification.set_notification_preferences(event_names)

      with {:ok, processed_req_hdrs} <-
             Utils.prep_headers(csr.user_access_token, processed_req_data),
           {:ok, resp} <-
             EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
           {:ok,
            %EbayXmlApi.Notification{
              SetNotificationPreferencesResponse: %{
                Ack: "Success"
              }
            }} <-
             Notification.get_notification_response(resp.body) do
        update_user_settings(csr, event_names, "Success")

        conn
        |> render("message.json",
          message: "Successfully subscribed for #{Enum.join(event_names, ", ")}"
        )
      else
        {:ok,
         %EbayXmlApi.Notification{
           SetNotificationPreferencesResponse: %{
             Ack: "Failure",
             Errors: errors
           }
         }} ->
          update_user_settings(csr, event_names, "Failure", errors[:ShortMessage])
          {:error, "Error #{errors[:ErrorCode]}"}

        {:error, _} ->
          {:error, "Error"}
      end
    rescue
      _ -> {:error, "System error, contact support team"}
    end
  end

  defp update_user_settings(csr, event_names, status, message \\ nil) do
    map = %{
      subscribed_at: DateTime.utc_now(),
      status: status,
      message: message
    }

    response = Enum.map(event_names, &Map.put(map, :event, &1))

    UserSettings.update_user_settings(csr.user_id, response, event_names)
  end

  def webhook(
        conn,
        %{
          GetItemTransactionsResponse: %{
            NotificationEventName: "FixedPriceTransaction",
            Item: %{ItemID: listing_id},
            TransactionArray: %{
              Transaction: %{Variation: item, QuantityPurchased: quantity_purchased}
            },
            RecipientUserID: user
          }
        } = params
      ) do
    with product when not is_nil(product) <-
           VariationProducts.get_product(item[:SKU], user, to_string(listing_id)),
         {:ok, quantity} <- update_quantity(product, quantity_purchased),
         {:ok, _} <- VariationProducts.update_product(product, %{quantity: quantity}) do
      get_log_map_for_variation(user, item[:SKU], quantity_purchased, params, "Success")
      |> append_log_file()

      conn
      |> Plug.Conn.resp(200, "")
      |> Plug.Conn.send_resp()
    else
      _ ->
        get_log_map_for_variation(user, item[:SKU], quantity_purchased, params, "Failed")
        |> append_log_file()

        {:error, "unknown"}
    end
  end

  def webhook(
        conn,
        %{
          GetItemTransactionsResponse: %{
            NotificationEventName: "FixedPriceTransaction",
            Item: %{SKU: sku, ItemID: listing_id},
            TransactionArray: %{Transaction: %{QuantityPurchased: quantity_purchased}},
            RecipientUserID: user
          }
        } = params
      ) do
    with product when not is_nil(product) <-
           Products.get_product(sku, user, to_string(listing_id)),
         {:ok, quantity} <- update_quantity(product, quantity_purchased),
         {:ok, _} <- Products.update_product(product, %{quantity: quantity}) do
      get_log_map_for_simple(user, sku, quantity_purchased, params, "Success")
      |> append_log_file()

      conn
      |> Plug.Conn.resp(200, "")
      |> Plug.Conn.send_resp()
    else
      _ ->
        get_log_map_for_simple(user, sku, quantity_purchased, params, "Failed")
        |> append_log_file()

        {:error, "unknown"}
    end
  end

  defp update_quantity(product, quantity) do
    if(product.quantity - quantity >= 0) do
      {:ok, product.quantity - quantity}
    else
      {:error, "invalid quantity"}
    end
  end

  def get_log_map_for_variation(user_id, sku, quantity, params, status) do
    transaction = get_in(params, [:GetItemTransactionsResponse, :TransactionArray, :Transaction])

    %{
      "Seller UserID" => user_id,
      "Buyer UserID" => get_in(transaction, [:Buyer, :UserID]),
      "ItemID" => get_in(params, [:GetItemTransactionsResponse, :Item, :ItemID]),
      "SKU" => "null",
      "Title" => "null",
      "QuantityPurchased" => quantity,
      "OrderID" => get_in(transaction, [:ContainingOrder, :OrderID]),
      "Variation SKU" => sku,
      "Variation Title" => get_in(transaction, [:Variation, :VariationTitle]),
      "Status" => status,
      "Transaction Time" => NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def get_log_map_for_simple(user_id, sku, quantity, params, status) do
    transaction = get_in(params, [:GetItemTransactionsResponse, :TransactionArray, :Transaction])

    %{
      "Seller UserID" => user_id,
      "Buyer UserID" => get_in(transaction, [:Buyer, :UserID]),
      "ItemID" => get_in(params, [:GetItemTransactionsResponse, :Item, :ItemID]),
      "SKU" => sku,
      "Title" => get_in(params, [:GetItemTransactionsResponse, :Item, :Title]),
      "QuantityPurchased" => quantity,
      "OrderID" => get_in(transaction, [:ContainingOrder, :OrderID]),
      "Variation SKU" => "null",
      "Variation Title" => "null",
      "Status" => status,
      "Transaction Time" => NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def append_log_file(map) do
    path = "priv/notification_logs/logs.csv"

    if(File.exists?(path)) do
      nil
    else
      File.mkdir_p!(Path.dirname(path))
      add_headers(map, path)
    end

    {:ok, opened_file} = File.open(path, [:append])

    map
    |> Map.values()
    |> Enum.join(",")
    |> (&IO.binwrite(opened_file, ~s(\n#{&1}))).()

    File.close(opened_file)
  end

  defp add_headers(map, path) do
    {:ok, opened_file} = File.open(path, [:append])

    map
    |> Map.keys()
    |> Enum.join(",")
    |> (&IO.binwrite(opened_file, ~s(#{&1}))).()

    File.close(opened_file)
  end
end
