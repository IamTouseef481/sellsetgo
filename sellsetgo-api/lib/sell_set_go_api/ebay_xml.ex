defmodule SellSetGoApi.EbayXml do
  @moduledoc false
  use HTTPoison.Base

  @app :sell_set_go_api

  def get_config, do: Application.get_env(@app, :ebay_api)
  def get_client_config, do: Application.get_env(@app, :ebay_oauth2_client)

  def process_request_url(url) do
    cfg = get_config()
    uri = URI.parse(url)

    case Map.get(uri, :host, nil) do
      nil -> Keyword.get(cfg, :site) <> url
      _any -> url
    end
  end

  def process_request_headers(headers) when is_map(headers) do
    Enum.into(headers, []) |> process_request_headers()
  end

  def process_request_headers(headers) do
    cfg = get_config()
    cl_cfg = get_client_config()

    headers ++
      [
        {"X-EBAY-API-DEV-NAME", Keyword.get(cfg, :dev_name)},
        {"X-EBAY-API-APP-NAME", Keyword.get(cl_cfg, :client_id)},
        {"X-EBAY-API-CERT-NAME", Keyword.get(cl_cfg, :client_secret)},
        {"Content-Type", "text/xml"}
      ]
  end
end
