defmodule SellSetGoApi.Orders.Orders do
  @moduledoc """
  The Orders context.
  """

  alias SellSetGoApi.Accounts.Users
  alias SellSetGoApi.Orders.Order
  alias SellSetGoApi.{LastFetchTime, OauthEbay, Repo, Utils}
  import Ecto.Query, warn: false

  def create_or_update_order_fetch_time(params) do
    params = Map.put(params, :type, "order")

    %LastFetchTime{}
    |> LastFetchTime.changeset(params)
    |> Repo.insert(
      conflict_target: [:user_id, :type],
      on_conflict: {:replace_all_except, [:id, :inserted_at]}
    )
  end

  def get_last_fetched_at(user_id) do
    now = DateTime.utc_now()

    last_fetched_time =
      from(lft in LastFetchTime)
      |> where([lft], lft.user_id == ^user_id and lft.type == "order")
      |> select([lft], lft.last_fetched_at)
      |> Repo.one()
      |> case do
        nil ->
          {:ok, user} = Users.get_user(user_id)
          DateTime.from_naive!(user.inserted_at, "Etc/UTC")

        order_fetch_time ->
          order_fetch_time
      end

    last_fetched_time =
      if Timex.diff(now, last_fetched_time, :days) > 90 do
        now
        |> Timex.shift(days: -90)
        |> Timex.shift(minutes: 5)
        |> DateTime.truncate(:millisecond)
        |> DateTime.to_string()
      else
        last_fetched_time
        |> DateTime.to_string()
        |> String.replace("Z", ".000Z")
      end
      |> String.replace(" ", "T")

    %{last_fetched_time: last_fetched_time, now: now}
  end

  def get_oauth_client(current_session_record) do
    OauthEbay.session_to_client("Bearer", Utils.get_host("order", "EBAY"), current_session_record)
    |> OAuth2.Client.put_header("content-type", "application/json")
  end

  def fetch_and_store_orders(%{user_id: user_id} = current_session_record) do
    %{last_fetched_time: last_fetched_time, now: now} = get_last_fetched_at(user_id)
    client = get_oauth_client(current_session_record)

    route =
      Utils.get_route("order", "EBAY") <>
        "?filter=lastmodifieddate:[#{last_fetched_time}]&limit=200"

    with {:ok, %OAuth2.Response{body: response}} <- OAuth2.Client.get(client, route),
         {total, _} <- create_orders_in_ssg(response["orders"], user_id, client),
         {:res, _response, _total, true} <- {:res, response, total, total == response["total"]} do
      create_or_update_order_fetch_time(%{user_id: user_id, last_fetched_at: now})
      {:ok, "#{total} orders fetched and stored"}
    else
      {:res, response, total, false} ->
        {:error, "#{response["total"]} orders fetched but #{total} only stored"}

      {:error, %OAuth2.Response{body: ""}} ->
        {:error, "Something went wrong in Ebay API call"}
    end
  end

  def create_orders_in_ssg(orders, user_id, client) do
    Enum.map(orders, fn order ->
      {:ok, creation_date, _} = order["creationDate"] |> DateTime.from_iso8601()
      {:ok, last_modified_date, _} = order["lastModifiedDate"] |> DateTime.from_iso8601()
      tracking_details = get_tracking_details(order["fulfillmentHrefs"], client)

      %{
        order_id: order["orderId"],
        creation_date: creation_date |> DateTime.truncate(:second),
        last_modified_date: last_modified_date |> DateTime.truncate(:second),
        order_fulfillment_status: order["orderFulfillmentStatus"],
        order_payment_status: order["orderPaymentStatus"],
        seller_id: order["sellerId"],
        buyer: order["buyer"],
        pricing_summary: order["pricingSummary"],
        payments: order["paymentSummary"],
        fulfillment_instructions: order["fulfillmentStartInstructions"],
        line_items: order["lineItems"],
        sales_record_ref: order["salesRecordReference"],
        tracking_details: tracking_details,
        user_id: user_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
    |> then(fn orders_to_insert ->
      Repo.insert_all(Order, orders_to_insert,
        conflict_target: [:user_id, :order_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )
    end)
  end

  def update_order(order, response_order, client) do
    {:ok, last_modified_date, _} = response_order["lastModifiedDate"] |> DateTime.from_iso8601()
    tracking_details = get_tracking_details(response_order["fulfillmentHrefs"], client)

    attrs = %{
      last_modified_date: last_modified_date |> DateTime.truncate(:second),
      order_fulfillment_status: response_order["orderFulfillmentStatus"],
      order_payment_status: response_order["orderPaymentStatus"],
      pricing_summary: response_order["pricingSummary"],
      payments: response_order["paymentSummary"],
      fulfillment_instructions: response_order["fulfillmentStartInstructions"],
      line_items: response_order["lineItems"],
      sales_record_ref: response_order["salesRecordReference"],
      tracking_details: tracking_details
    }

    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  def get_order(%{user_id: user_id, order_id: order_id}) do
    from(o in Order)
    |> where([o], o.user_id == ^user_id and o.order_id == ^order_id)
    |> Repo.one()
    |> Utils.wrap_result(__MODULE__)
  end

  def list_orders(user_id, %{"page_size" => page_size, "page_no" => page_no}) do
    from(o in Order)
    |> where([o], o.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.paginate(%{page_size: page_size, page: page_no})
  end

  def update_tracking_no(
        %{user_id: user_id} = current_session_record,
        %{"order_id" => order_id} = params
      ) do
    client = get_oauth_client(current_session_record)
    route = Utils.get_route("order", "EBAY") <> "/#{order_id}/shipping_fulfillment"

    with {:ok, order} <- get_order(%{user_id: user_id, order_id: order_id}),
         {:ok, request} <-
           stitch_shipping_fulfillment(params, order),
         {:ok, %OAuth2.Response{body: _response}} <- OAuth2.Client.post(client, route, request),
         route <- Utils.get_route("order", "EBAY") <> "/#{order_id}",
         {:ok, %OAuth2.Response{body: response_order}} <- OAuth2.Client.get(client, route) do
      update_order(order, response_order, client)
    end
  end

  defp get_tracking_details(hrefs, client) do
    hrefs
    |> Enum.uniq()
    |> Enum.reduce([], fn href, acc ->
      route = String.trim_leading(href, Utils.get_host("order", "EBAY"))

      case OAuth2.Client.get(client, route) do
        {:ok, %OAuth2.Response{body: response}} ->
          [response] ++ acc

        _ ->
          acc
      end
    end)
  end

  defp stitch_shipping_fulfillment(params, order) do
    line_items =
      Enum.map(order.line_items, fn line_item ->
        %{
          "lineItemId" => line_item["lineItemId"],
          "quantity" => line_item["quantity"]
        }
      end)

    data =
      %{
        "trackingNumber" => params["tracking_no"],
        "shippingCarrierCode" => params["shipping_carrier"],
        "lineItems" => line_items
      }
      |> Utils.add_key_to_map_if_value_exist("shippedDate", params["shipped_date"])

    {:ok, data}
  end
end
