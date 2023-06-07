defmodule SellSetGoApiWeb.OrderController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.Orders.Orders
  action_fallback(SellSetGoApiWeb.FallbackController)

  def show(%{assigns: %{current_session_record: current_session_record}} = conn, %{
        "type" => "fetch"
      }) do
    with {:ok, orders} <- Orders.fetch_and_store_orders(current_session_record) do
      render(conn, "message.json", message: orders)
    end
  end

  def show(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "list"} = params
      ) do
    orders = Orders.list_orders(user_id, params)

    render(conn, "message.json",
      message: %{
        entries: orders.entries,
        total_entries: orders.total_entries,
        total_pages: orders.total_pages
      }
    )
  end

  def update(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "update_tracking_no"} = params
      ) do
    with {:ok, order} <- Orders.update_tracking_no(current_session_record, params) do
      render(conn, "order.json", order: order)
    end
  end
end
