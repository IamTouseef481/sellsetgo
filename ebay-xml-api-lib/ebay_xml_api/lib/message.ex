defmodule EbayXmlApi.Message do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.{Utils, XmlUtils}

  defstruct MemberMessageExchange: []

  @doc """
  https://developer.ebay.com/devzone/xml/docs/Reference/eBay/GetMemberMessages.html
  """
  # =======================================================================================================================
  # ==============================================Member Messages==========================================================
  # =======================================================================================================================
  def message(
        kw_list \\ [
          start_time: DateTime.utc_now() |> DateTime.to_string(),
          # adding 30 minutes to current time
          end_time: DateTime.add(DateTime.utc_now(), 1800, :second) |> DateTime.to_string(),
          entries_per_page: 40,
          page_number: 1
        ]
      ) do
    document([
      element(
        :GetMemberMessagesRequest,
        %{xmlns: "urn:ebay:apis:eBLBaseComponents"},
        start_time(kw_list[:start_time]) ++
          end_time(kw_list[:end_time]) ++
          pagination(kw_list[:entries_per_page], kw_list[:page_number]) ++
          [element(:MailMessageType, :All)]
      )
    ])
  end

  def start_time(value) when is_nil(value) == false, do: [element(:StartCreationTime, value)]
  def start_time(_value), do: []
  def end_time(value) when is_nil(value) == false, do: [element(:EndCreationTime, value)]
  def end_time(_value), do: []

  def   pagination(number, page) when number <= 200 and number >= 25 and page > 0,
    do: [element(:Pagination, [element(:EntriesPerPage, number), element(:PageNumber, page)])]

  def pagination(_number, _page),
    do: [element(:Pagination, [element(:EntriesPerPage, 25), element(:PageNumber, 1)])]

  def get_member_messages(kw_list \\ []) do
    body =
      if kw_list == [] do
        message()
      else
        message(kw_list)
      end
      |> generate

    %{
      body: body,
      call: Utils.camel_case(__ENV__.function),
      com_lvl: 1247,
      size: byte_size(body)
    }
  end

  def get_member_messages_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> may_be_add_member_message_field()
      |> get_in([:"#{Utils.camel_case(__ENV__.function)}", :MemberMessage])

    {:ok, struct(__MODULE__, resp_map)}
  end

  defp may_be_add_member_message_field(
         %{GetMemberMessagesResponse: %{MemberMessage: _MemberMessage}} = resp_map
       ) do
    resp_map
  end

  defp may_be_add_member_message_field(%{GetMemberMessagesResponse: resp_map}) do
    resp_map = resp_map |> Map.put(:MemberMessage, %{})

    %{GetMemberMessagesResponse: resp_map}
  end

  # =======================================================================================================================
  # ===================================================Reply Messages======================================================
  # =======================================================================================================================
  @doc """
  https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/AddMemberMessageRTQ.html
  """
  def reply_message(kw_list) do
    document([
      element(
        :AddMemberMessageRTQRequest,
        %{xmlns: "urn:ebay:apis:eBLBaseComponents"},
        [
          element(
            :MemberMessage,
            [element(:Body, kw_list[:body])] ++
              [element(:ParentMessageID, kw_list[:parent_message_id])] ++
              [element(:RecipientID, kw_list[:recipient_id])]
          )
        ]
      )
    ])
  end

  def get_reply_messages(kw_list \\ []) do
    body = reply_message(kw_list) |> generate

    %{
      body: body,
      call: Utils.camel_case("AddMemberMessageRTQ"),
      com_lvl: 1247,
      size: byte_size(body)
    }
  end

  def get_reply_messages_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:AddMemberMessageRTQResponse])

    {:ok, resp_map}
  end
end
