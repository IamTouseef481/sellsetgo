defmodule EbayXmlApi.Trading do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.XmlUtils

  # For future use
  # %{
  #   BuyItNowPrice: 1.0,
  #   ClassifiedAdPayPerLeadFee: 0.0,
  #   ItemID: '',
  #   ListingDetails: %{
  #     StartTime: ~N[2022-03-17 11:25:43.000],
  #     ViewItemURL: "url",
  #     ViewItemURLForNaturalSearch: "url"
  #   },
  #   ListingDuration: "GTC",
  #   ListingType: "FixedPriceItem",
  #   PictureDetails: nil,
  #   Quantity: 1,
  #   QuantityAvailable: 1,
  #   SKU: "",
  #   SellerProfiles: %{
  #     SellerPaymentProfile: %{
  #       PaymentProfileID: 29494899024,
  #       PaymentProfileName: "Payment on collection accepted..."
  #     }
  #   },
  #   SellingStatus: %{CurrentPrice: 1.0},
  #   ShippingDetails: %{
  #     GlobalShipping: true,
  #     ShippingServiceOptions: %{ShippingServiceCost: 2.0},
  #     ShippingType: "Flat"
  #   },
  #   TimeLeft: "",
  #   Title: "test item do not buy"
  # }

  defstruct ItemArray: %{
              Item: [
                %{
                  ItemID: nil,
                  SKU: nil,
                  Title: nil,
                  BuyItNowPrice: nil,
                  ListingType: nil,
                  QuantityAvailable: nil,
                  Variations: nil
                }
              ]
            },
            PaginationResult: %{
              TotalNumberOfEntries: 0,
              TotalNumberOfPages: 0
            }

  def ebay_selling(kw_list) do
    document([
      element(
        :GetMyeBaySellingRequest,
        %{xmlns: "urn:ebay:apis:eBLBaseComponents"},
        [
          element(
            :ActiveList,
            [
              element(
                :Pagination,
                [
                  element(:EntriesPerPage, "#{kw_list[:entries]}"),
                  element(:PageNumber, "#{kw_list[:page_number]}")
                ]
              )
            ]
          )
        ]
      )
    ])
  end

  def my_ebay_selling(kw_list) do
    body = ebay_selling(kw_list) |> generate

    %{
      body: body,
      call: "GetMyeBaySelling",
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  def get_my_ebay_sell_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:GetMyeBaySellingResponse, :ActiveList]) || %{}

    if(resp_map != %{})do
      {:ok, struct(__MODULE__, resp_map)}
      else
      {:ok, "No selling record was found from Ebay"}
    end
  end

  def update_sku(kw_list) do
    body = update_sku_xml(kw_list) |> generate

    %{
      body: body,
      call: "ReviseFixedPriceItem",
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  def update_sku_xml(kw_list) do
    document([
      element(
        :ReviseFixedPriceItemRequest,
        %{xmlns: "urn:ebay:apis:eBLBaseComponents"},
        [
          element(
            :Item,
            [element(:ItemID, "#{kw_list[:item_id]}"), element(:SKU, "#{kw_list[:sku]}")]
          )
        ]
      )
    ])
  end

  def get_update_sku_resp(xml_response) do
    resp_json =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:ReviseFixedPriceItemResponse])

    {:ok, resp_json}
  end
end
