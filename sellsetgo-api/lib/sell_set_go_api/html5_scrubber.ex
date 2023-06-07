defmodule SellSetGoApi.Html5Scrubber do
  @moduledoc false
  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  require SellSetGoApi.Configurations
  alias SellSetGoApi.Configurations

  Meta.remove_cdata_sections_before_scrub()
  Configurations.allow_comments()

  def scrub({"script", _attributes, _children}) do
    {""}
  end

  def scrub({tag, attributes, children}) do
    {tag, scrub_attributes(tag, attributes), children}
  end

  def scrub({_token, children}), do: children

  def scrub(text) do
    text
  end

  @doc false
  def scrub_attributes(tag, attributes) do
    Enum.map(attributes, fn attr -> scrub_attribute(tag, attr) end)
    |> Enum.reject(&is_nil(&1))
  end

  def scrub_attribute("script", _attribute) do
    nil
  end

  def scrub_attribute(_tag, attribute) do
    attribute
  end
end
