defmodule EbayXmlApi.XmlUtils do
  @moduledoc false
  @doc """
  `parse_xml_to_map(xml_doc, :normal)` has two types of map derivation
  - `:normal` mode, which will produce a XML equivalent
     mapping structure of the form
     %{ElementName => %{
         "attrs" => ElementAttributesMap,
         "content" => ElementChildrenList
      }
    Each and every children will be following the same
    pattern
  ```elixir
  iex(1)> xml = "<AboutUs><Welcome>Hello</Welcome>J<Hello /></AboutUs>"
  "<AboutUs><Welcome>Hello</Welcome>J<Hello /></AboutUs>"
  iex(2)> EbayXmlApi.XmlUtils.parse_xml_to_map(:normal, xml)
  %{
    "AboutUs" => %{
      "attrs" => %{},
      "content" => [
        %{"Hello" => %{"attrs" => %{}, "content" => []}},
        %{"Welcome" => %{"attrs" => %{}, "content" => ["Hello"]}},
        "J"
      ]
    }
  }
  ```
  - `parse_xml_to_map(xml_doc, :naive)` mode, which will produce a naive version of XML document.
    All XML attributes will be omitted in this method. Also, the XML
    document must be well formed without hanging text children.
  The Map Structure takes the form of simple key value, where the
  key represents XML Element Name and the Value is the Content between
  the XML Element
  %{ ElementName => ElementValue }
  ```elixir
  iex(6)> a = "<AboutUs><Welcome>123</Welcome><Welcome>Hello</Welcome><helo><h1></h1></helo><helo>12</helo><Welcome>HELO</Welcome></AboutUs>"
  "<AboutUs><Welcome>123</Welcome><Welcome>Hello</Welcome><helo><h1></h1></helo><helo>12</helo><Welcome>HELO</Welcome></AboutUs>"
  iex(7)> a |> EbayXmlApi.XmlUtils.parse_xml_to_map(:naive)
  %{
  "AboutUs" => %{
      "Welcome" => ["123", "Hello", "HELO"],
      "helo" => [%{"h1" => nil}, "12"]
    }
  }
  ```
  """
  def parse_xml_to_map(xml, :normal) do
    xml
    |> clean()
    |> SweetXml.parse()
    |> parse_xml(%{})
  end

  def parse_xml_to_map(xml, :naive) do
    xml
    |> clean()
    |> SweetXml.parse()
    |> parse_naive_xml(%{})
  end

  def clean(xml_doc) do
    xml_doc
    |> String.replace(~r/(\n|  )/, "")
    |> String.replace(~r/> /, ">")
    |> String.replace(~r/ </, "<")
  end

  defp parse_xml([], []), do: nil
  defp parse_xml([], acc), do: acc

  defp parse_xml(
         {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, attrs, [],
          _lang, _xmlbase, _elementdef},
         acc
       ) do
    old_content = acc |> Map.get("content", [])

    merged_map =
      attrs
      |> parse_xml(%{"attrs" => %{}})
      |> Map.merge(parse_xml([], %{"content" => old_content}))

    acc
    |> Map.update("#{name}", merged_map, fn old ->
      Map.merge(old, merged_map)
    end)
  end

  defp parse_xml(
         {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, attrs, content,
          _lang, _xmlbase, _elementdef},
         acc
       ) do
    merged_map =
      attrs
      |> parse_xml(%{"attrs" => %{}})
      |> Map.merge(content |> parse_xml(%{"content" => []}))

    acc
    |> Map.update("#{name}", merged_map, fn old ->
      Map.merge(old, merged_map)
    end)
  end

  defp parse_xml(
         [
           {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, attrs,
            content, _lang, _xmlbase, _elementdef}
           | t
         ],
         acc
       ) do
    merged_map =
      attrs
      |> parse_xml(%{"attrs" => %{}})
      |> Map.merge(content |> parse_xml(%{"content" => []}))

    parse_xml(
      t,
      acc
      |> Map.update("content", [%{"#{name}" => merged_map}], fn old ->
        [%{"#{name}" => merged_map} | old] |> Enum.sort()
      end)
    )
  end

  defp parse_xml([{:xmlComment, _parents, _pos, _lang, value} | t], acc) do
    comment =
      %{}
      |> Map.put("content", ["#{value}"])

    parse_xml(
      t,
      acc
      |> Map.update("content", [%{"comment" => comment}], fn old ->
        [%{"comment" => comment} | old] |> Enum.sort()
      end)
    )
  end

  defp parse_xml([{:xmlPI, name, _parents, _pos, value} | t], acc) do
    merged_map = Map.put(%{}, "attrs", form_xmlpi_attrs(value))

    parse_xml(
      t,
      acc
      |> Map.update("content", [%{"#{name}" => merged_map}], fn old ->
        [%{"#{name}" => merged_map} | old] |> Enum.sort()
      end)
    )
  end

  defp parse_xml([{:xmlText, _parents, _pos, _lang, '\n  ', :text} | t], acc),
    do: parse_xml(t, acc)

  defp parse_xml([{:xmlText, _parents, _pos, _lang, '\n', :text} | t], acc), do: parse_xml(t, acc)

  defp parse_xml([{:xmlText, _parents, _pos, _lang, '\n ', :text} | t], acc),
    do: parse_xml(t, acc)

  defp parse_xml([{:xmlText, _parents, _pos, _lang, '\t', :text} | t], acc), do: parse_xml(t, acc)
  defp parse_xml([{:xmlText, _parents, _pos, _lang, '\r', :text} | t], acc), do: parse_xml(t, acc)
  defp parse_xml([{:xmlText, _parents, _pos, _lang, '  ', :text} | t], acc), do: parse_xml(t, acc)

  defp parse_xml([{:xmlText, _parents, _pos, _lang, '\n\t', :text} | t], acc),
    do: parse_xml(t, acc)

  defp parse_xml([{:xmlText, _parents, _pos, _lang, value, :text} | t], acc) do
    parse_xml(t, acc |> Map.update("content", value, fn old -> ["#{value}" | old] end))
  end

  defp parse_xml(
         [
           {:xmlAttribute, name, _expanded__name, _ns_info, _namespace, _parents, _pos, _lang,
            value, _normalized}
           | t
         ],
         acc
       ) do
    attrs = Map.put(%{}, "#{name}", "#{value}")

    parse_xml(t, acc |> Map.update("attrs", attrs, fn old -> Map.merge(old, attrs) end))
  end

  defp form_xmlpi_attrs(value) do
    "#{value}"
    |> String.split(" ")
    |> Enum.reduce(%{}, fn val, acc ->
      [k, v] = String.split(val, "=")
      Map.put(acc, k, v)
    end)
    |> Map.put("kind", "xmlPI")
  end

  defp parse_naive_xml([], []), do: nil
  defp parse_naive_xml([], acc), do: acc

  defp parse_naive_xml(
         {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, _attrs, [],
          _lang, _xmlbase, _elementdef},
         acc
       ) do
    old_content = acc |> Map.get("#{name}", %{})
    new_content = parse_naive_xml([], old_content)

    acc
    |> Map.update(name, new_content, fn old ->
      Map.merge(old, new_content)
    end)
  end

  defp parse_naive_xml(
         [
           {:xmlElement, :ItemPrice, _expanded_name, _ns_info, _namespace, _parents, _pos,
            [{:xmlAttribute, attr_name, _, _, _, _, _, _, attr_content, _} | _tail], content,
            _lang, _xmlbase, _elementdef}
         ],
         acc
       ) do
    new_content = content |> parse_naive_xml(acc)

    acc
    |> Map.put(attr_name, attr_content)
    |> Map.update(:ItemPrice, new_content, fn old ->
      [new_content | old]
    end)
  end

  defp parse_naive_xml(
         {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, _attrs,
          content, _lang, _xmlbase, _elementdef},
         acc
       ) do
    new_content = content |> parse_naive_xml(acc)

    acc
    |> Map.update(name, new_content, fn old ->
      [new_content | old]
    end)
  end

  defp parse_naive_xml(
         [
           {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, _attrs, [],
            _lang, _xmlbase, _elementdef}
           | t
         ],
         acc
       ) do
    new_content =
      case parse_naive_xml([], acc) do
        %{} -> nil
        other -> other
      end

    parse_naive_xml(
      t,
      acc
      |> Map.update(name, new_content, fn old ->
        [new_content | old]
      end)
    )
  end

  defp parse_naive_xml(
         [
           {:xmlElement, name, _expanded_name, _ns_info, _namespace, _parents, _pos, _attrs,
            content, _lang, _xmlbase, _elementdef}
           | t
         ],
         acc
       ) do
    new_content = content |> parse_naive_xml(%{})

    parse_naive_xml(
      t,
      acc
      |> Map.update(name, new_content, fn old ->
        [old | [new_content]] |> List.flatten()
      end)
    )
  end

  defp parse_naive_xml([{:xmlComment, _parents, _pos, _lang, _value} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlPI, _name, _parents, _pos, _value} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '\n  ', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '\n', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '\n ', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '\t', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '\r', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '  ', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml([{:xmlText, _parents, _pos, _lang, '\n\t', :text} | t], acc),
    do: parse_naive_xml(t, acc)

  defp parse_naive_xml(
         [{:xmlText, [{:SKU, _}| _], _pos, _lang, value, :text} | t],
         _acc
       ) do
    parse_naive_xml(t, "#{value}")
  end

  defp parse_naive_xml(
         [{:xmlText, _parents, _pos, _lang, value, :text} | t],
         _acc
       ) do
    parse_naive_xml(t, change_value("#{value}"))
  end

  defp change_value(value) when is_binary(value) and value == "true", do: true
  defp change_value(value) when is_binary(value) and value == "false", do: false

  defp change_value(value) when is_binary(value), do: convert_value(value)

  defp convert_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int

      {_any, _other} ->
        check_float(value)

      :error ->
        value
    end
  end

  defp check_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} ->
        float

      {_anyf, _otherbin} ->
        check_timestamp(value)

      :error ->
        value
    end
  end

  defp check_timestamp(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, dt} -> dt
      {:error, :invalid_format} -> value
    end
  end
end
