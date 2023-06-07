# EbayXmlApi

EbayXmlApi is set of abstractions to interact with EBAY XMP API Web Server
written specifically for the application SELLSETGO by elixirexperts making
it a convenient wrapper / library to produce request XML docs and parse
response XML docs.

Add `ebay_xml_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ebay_xml_api, path: "../ebay-xml-api-lib/ebay_xml_api"}
  ]
end
