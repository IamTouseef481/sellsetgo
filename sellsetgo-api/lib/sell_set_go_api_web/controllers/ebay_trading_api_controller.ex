defmodule SellSetGoApiWeb.EbayTradingApiController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.EbayTradingApi

  action_fallback SellSetGoApiWeb.FallbackController

  def update(conn, %{"id" => item_id, "sku" => sku} = _params) do
    access_token = SellSetGoApi.get_access_token(conn)
    headers = conn
    |> SellSetGoApi.get_global_id()
    |> EbayTradingApi.get_site_id_from_global_id()
    |> EbayTradingApi.ebay_request_headers("ReviseFixedPriceItem", access_token)

    body = EbayTradingApi.ebay_update_sku_request_body(item_id, sku)
    with {:ok, response} <- EbayTradingApi.ebay_api_request(body, headers, "ReviseFixedPriceItem") do
      render(conn, "index.json", data: response)
    end
  end
end
