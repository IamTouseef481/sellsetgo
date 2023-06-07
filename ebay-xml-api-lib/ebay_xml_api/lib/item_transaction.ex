defmodule EbayXmlApi.ItemTransaction do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.{Utils, XmlUtils}

  defstruct QuantitySold: nil

  def item_transaction(kw_list) do
    body=document([
      element(:GetItemTransactionsRequest,%{xmlns: "urn:ebay:apis:eBLBaseComponents"},kw_list)
    ])
  end

  def get_item_transaction(kw_list) do
    body = item_transaction(kw_list) |> generate

    %{
      body: body,
      call: "GetItemTransactions",
      com_lvl: 1225,
      size: byte_size(body)
    }
  end


  def get_item_transaction_response(xml) do
    resp_map =
      xml
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:GetItemTransactionsResponse, :Item, :SellingStatus])
      if (resp_map) do
        {:ok, struct(__MODULE__, resp_map)}
      else
        {:ok, %EbayXmlApi.ItemTransaction{}}
      end

  end

  
end
