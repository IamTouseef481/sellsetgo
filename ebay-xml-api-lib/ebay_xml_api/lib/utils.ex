defmodule EbayXmlApi.Utils do
  @moduledoc false

  import SweetXml

  def extract_fn_name({fn_name, _}), do: fn_name
  def extract_fn_name(:string, {fn_name, _}), do: Kernel.to_string(fn_name)

  def camel_case(fn_name) when is_binary(fn_name), do: Macro.camelize(fn_name)

  def camel_case(fn_name) when is_atom(fn_name),
    do: fn_name |> Kernel.to_string() |> Macro.camelize()

  def camel_case(attr) when is_tuple(attr), do: attr |> extract_fn_name() |> camel_case()

  def extract_xml_kw(xml, main_param, params \\ [])
  def extract_xml_kw(_xml, _any, []), do: %{}

  def extract_xml_kw(xml, main_param, params) do
    ext_params = param_ext(params, Keyword.new([]))

    xml
    |> xpath(
      ~x"""
      //#{Macro.camelize("#{main_param}")}
      """,
      ext_params
    )
  end

  def param_ext([], acc), do: acc

  def param_ext([{param, :string} | t], acc) do
    param_ext(
      t,
      Keyword.put(acc, param, ~x"""
      ./#{Macro.camelize("#{param}")}/text()
      """s)
    )
  end

  def param_ext([{param, :integer} | t], acc) do
    param_ext(
      t,
      Keyword.put(acc, param, ~x"""
      ./#{Macro.camelize("#{param}")}/text()
      """i)
    )
  end

  def param_ext([{param, :float} | t], acc) do
    param_ext(
      t,
      Keyword.put(acc, param, ~x"""
      ./#{Macro.camelize("#{param}")}/text()
      """f)
    )
  end

  def param_ext([{param, :list} | t], acc) do
    param_ext(
      t,
      Keyword.put(acc, param, ~x"""
      ./#{Macro.camelize("#{param}")}/text()
      """l)
    )
  end
end
