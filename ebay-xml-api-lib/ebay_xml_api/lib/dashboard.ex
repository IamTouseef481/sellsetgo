defmodule EbayXmlApi.Dashboard do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.{Utils, XmlUtils}

  defstruct FeedbackDetailArray: %{},
            FeedbackSummary: %{}

  # Feedback Context

  def feedback(kw_list) do
    document([
      element(:GetFeedbackRequest, %{xmlns: "urn:ebay:apis:eBLBaseComponents"}, kw_list)
    ])
  end

  def get_feedback(kw_list) do
    body = feedback(kw_list) |> generate

    %{
      body: body,
      call: Utils.camel_case(__ENV__.function),
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  def get_feedback_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:"#{Utils.camel_case(__ENV__.function)}"])

    {:ok, struct(__MODULE__, resp_map)}
  end
end
