defmodule EbayXmlApi.User do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.{Utils, XmlUtils}

  defstruct Site: nil,
            Status: nil,
            UserID: nil,
            UserIDChanged: nil,
            UserIDLastChanged: nil,
            BusinessRole: nil,
            EBaySubscription: nil,
            EIASToken: nil,
            Email: nil,
            EnterpriseSeller: nil,
            IDVerified: nil,
            NewUser: nil,
            RegistrationDate: nil

  @doc """
  https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/GetUser.html#GetUser
  The Ebay API Server responds with the following data:
  <?xml version="1.0" encoding="UTF-8"?>
  <GetUserResponse xmlns="urn:ebay:apis:eBLBaseComponents">
   <Timestamp>2021-10-06T12:23:56.335Z</Timestamp>
   <Ack>Success</Ack>
   <Version>1207</Version>
   <Build>E1207_CORE_APISIGNIN_19151597_R1</Build>
   <User>
      <AboutMePage>false</AboutMePage>
      <EIASToken>nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4aiDZeBpA2dj6x9nY+seQ==</EIASToken>
      <Email>user3@dzine-hub.com</Email>
      <FeedbackScore>500</FeedbackScore>
      <UniqueNegativeFeedbackCount>0</UniqueNegativeFeedbackCount>
      <UniquePositiveFeedbackCount>0</UniquePositiveFeedbackCount>
      <PositiveFeedbackPercent>0.0</PositiveFeedbackPercent>
      <FeedbackPrivate>false</FeedbackPrivate>
      <IDVerified>true</IDVerified>
      <eBayGoodStanding>true</eBayGoodStanding>
      <NewUser>false</NewUser>
      <RegistrationDate>2006-01-01T00:00:00.000Z</RegistrationDate>
      <Site>UK</Site>
      <Status>Confirmed</Status>
      <UserID>testuser_dzuser3</UserID>
      <UserIDChanged>true</UserIDChanged>
      <UserIDLastChanged>2021-09-27T08:02:55.000Z</UserIDLastChanged>
      <VATStatus>VATTax</VATStatus>
      <SellerInfo>
         <AllowPaymentEdit>true</AllowPaymentEdit>
         <CheckoutEnabled>true</CheckoutEnabled>
         <CIPBankAccountStored>false</CIPBankAccountStored>
         <GoodStanding>true</GoodStanding>
         <LiveAuctionAuthorized>false</LiveAuctionAuthorized>
         <MerchandizingPref>OptIn</MerchandizingPref>
         <QualifiesForB2BVAT>false</QualifiesForB2BVAT>
         <SellerGuaranteeLevel>NotEligible</SellerGuaranteeLevel>
         <SchedulingInfo>
            <MaxScheduledMinutes>30240</MaxScheduledMinutes>
            <MinScheduledMinutes>0</MinScheduledMinutes>
            <MaxScheduledItems>3000</MaxScheduledItems>
         </SchedulingInfo>
         <StoreOwner>false</StoreOwner>
         <PaymentMethod>NothingOnFile</PaymentMethod>
         <CharityRegistered>false</CharityRegistered>
         <SafePaymentExempt>true</SafePaymentExempt>
         <TransactionPercent>0.0</TransactionPercent>
         <RecoupmentPolicyConsent />
         <DomesticRateTable>false</DomesticRateTable>
         <InternationalRateTable>false</InternationalRateTable>
      </SellerInfo>
      <BusinessRole>FullMarketPlaceParticipant</BusinessRole>
      <EBaySubscription>FileExchange</EBaySubscription>
      <UserSubscription>FileExchange</UserSubscription>
      <eBayWikiReadOnly>false</eBayWikiReadOnly>
      <MotorsDealer>false</MotorsDealer>
      <UniqueNeutralFeedbackCount>0</UniqueNeutralFeedbackCount>
      <EnterpriseSeller>false</EnterpriseSeller>
   </User>
  </GetUserResponse>
  """

  def user(kw_list) do
    document([
      element(:GetUserRequest, %{xmlns: "urn:ebay:apis:eBLBaseComponents"}, kw_list)
    ])
  end

  def get_user(kw_list) do
    body = user(kw_list) |> generate

    %{
      body: body,
      call: Utils.camel_case(__ENV__.function),
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  def get_user_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:"#{Utils.camel_case(__ENV__.function)}", :User])

    {:ok, struct(__MODULE__, resp_map)}
  end
end
