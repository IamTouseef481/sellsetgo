defmodule SellSetGoApi.Items do
  @moduledoc """
      Context file for items
  """
  alias SellSetGoApi.Utils
  alias EbayXmlApi.ItemTransaction
  alias SellSetGoApi.{EbayXml, Utils}

  def get_route(params) do
    base_route = Utils.get_route("inventory_item")

    case params do
      %{"sku" => sku} ->
        {:ok, base_route <> "/#{sku |> URI.encode(&URI.char_unreserved?/1)}"}

      %{"limit" => limit, "offset" => offset} ->
        {:ok, base_route <> "?limit=#{limit}&offset=#{offset}"}

      _ ->
        {:error, "route not found"}
    end
  end

  def get_quantity_sold(%{user_access_token: uat}, item_id, marketplace_id) do
    with processed_req_data <-
           ItemTransaction.get_item_transaction(
             RequesterCredentials: [eBayAuthToken: uat],
             ItemID: item_id
           ),
         {:ok, processed_req_hdrs} <-
           Utils.prep_headers(uat, processed_req_data, Utils.get_site_id(marketplace_id)),
         {:ok, %{body: body}} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         {:ok, count} <-
           ItemTransaction.get_item_transaction_response(body) do
      Map.get(count, :QuantitySold)
    end
  end
end
