defmodule EbayXmlApi.Notification do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.{Utils, XmlUtils}

  defstruct SetNotificationPreferencesResponse: %{
              Timestamp: nil,
              Ack: nil,
              Build: nil
            }


  def notification(kw_list) do
    document([
      element(:SetNotificationPreferencesRequest, %{xmlns: "urn:ebay:apis:eBLBaseComponents"}, kw_list)
    ])
  end

  def set_notification_preferences(event_names) do
    kw_list = subscribe_req_body(event_names)
    body = notification(kw_list) |> generate

    %{
      body: body,
      call: Utils.camel_case(__ENV__.function),
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  defp subscribe_req_body(event_names)do
    [UserDeliveryPreferenceArray: Enum.reduce(event_names, [], & &2 ++ [NotificationEnable: [EventType: &1, EventEnable: "Enable"]])]
  end

  def get_notification_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)

      build_response(resp_map)
  end

  defp build_response(response)do
      {:ok, struct(__MODULE__, response)}
  end
end
