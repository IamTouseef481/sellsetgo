defmodule SellSetGoApiWeb.MiscController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.EbayTradingApi

  action_fallback SellSetGoApiWeb.FallbackController

  def dashboard(conn, _params) do
    feedback = get_feedback(conn)
    render(conn, "index.json", data: feedback)
  end

  def get_feedback(conn) do
    access_token = SellSetGoApi.get_access_token(conn)
    headers = conn
    |> SellSetGoApi.get_global_id()
    |> EbayTradingApi.get_site_id_from_global_id()
    |> EbayTradingApi.ebay_request_headers("GetFeedback", access_token)

    body = EbayTradingApi.ebay_get_feedback_request_body()
    with {:ok, response} <- EbayTradingApi.ebay_api_request(body, headers, "GetFeedback") do
      response
    end
  end
end
