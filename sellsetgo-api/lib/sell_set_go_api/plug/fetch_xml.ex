defmodule SellSetGoApi.Plug.FetchXml do
  @moduledoc false

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    try do
      case read_body(conn) do
        {:ok, xml, _} ->
          body_params =
            EbayXmlApi.XmlUtils.parse_xml_to_map(xml, :naive)[:"soapenv:Envelope"][
              :"soapenv:Body"
            ]

          %{conn | params: body_params}
      end
    rescue
      _ -> invalid_format(conn)
    end
  end

  def invalid_format(conn) do
    conn
    |> configure_session(drop: true)
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{"error" => %{"details" => "invalid format"}}))
    |> halt()
  end
end
