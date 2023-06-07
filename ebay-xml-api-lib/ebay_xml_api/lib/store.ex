defmodule EbayXmlApi.Store do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.{Utils, XmlUtils}

  defstruct CustomCategories: %{
              CustomCategory: [
                %{
                  CategoryID: nil,
                  Name: nil,
                  Order: nil
                }
              ]
            },
            Name: nil

  @doc """
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<GetStoreResponse xmlns=\"urn:ebay:apis:eBLBaseComponents\">
  <Timestamp>2021-12-09T14:01:43.460Z</Timestamp>
  <Ack>Success</Ack>
    <Version>1177</Version>
  <Build>E1177_CORE_API5_19110890_R1</Build>
  <Store>
    <Name>dzinehub</Name>
    <URLPath>dzinehub</URLPath>
    <URL>http://www.ebay.co.uk/str/dzinehub</URL>
    <SubscriptionLevel>Basic</SubscriptionLevel>
    <Description>dZine-Hub is the new way to get a professional branded eBay design that will multiply your sales. Our eBay Template design &amp;
      eBay Store branding package is: 100% active content compliant, 2018 Spring seller update compliant, https:// secure, Optimized for eBay’s Cassini
      search algorithm, Mobile &amp; Tablet responsive, Customizable for all ebay seller tools</Description>
    <Logo>
      <URL>https://i.ebayimg.com/00/s/MzAwWDMwMA==/z/qmsAAOSwpzNgeWVY/$_7.JPG</URL>
    </Logo>
  <Theme>
    <ThemeID>1000000</ThemeID>
    <ColorScheme>
      <ColorSchemeID>1000005</ColorSchemeID>
      <Color>
        <Primary>0C04B8</Primary>
        <Secondary>CFEBFF</Secondary>
        <Accent>0099FF</Accent>
      </Color>
      <Font>
        <NameColor>FFFFFF</NameColor>
        <TitleColor>FFFFFF</TitleColor>
        <DescColor>333333</DescColor>
      </Font>
    </ColorScheme>
  </Theme>
  <HeaderStyle>Full</HeaderStyle>
  <HomePage>41686514</HomePage>
  <ItemListLayout>ListView</ItemListLayout>
  <ItemListSortOrder>CustomCode</ItemListSortOrder>
  """

  def store(kw_list) do
    document([
      element(:GetStoreRequest, %{xmlns: "urn:ebay:apis:eBLBaseComponents"}, kw_list)
    ])
  end

  def get_store(kw_list) do
    body = store(kw_list) |> generate

    %{
      body: body,
      call: Utils.camel_case(__ENV__.function),
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  def get_store_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)

      build_response(resp_map)
  end

  defp build_response(response)do
    store_categories=get_in(response, [:GetStoreResponse, :Store])
    if !is_nil(store_categories) do
      {:ok, struct(__MODULE__, store_categories)}
      else
      {:error, response}
    end
  end
end
