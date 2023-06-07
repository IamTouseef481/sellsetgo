defmodule SellSetGoApi.Utils do
  @moduledoc false

  @app :sell_set_go_api
  alias ExAws.{Config, S3}
  import Ecto.Query, warn: false
  require Logger

  alias SellSetGoApi.Admin.{EbaySiteDetails, Host, Route}
  alias SellSetGoApi.Repo

  def generate_rand_str(bytes \\ 16, opts \\ [case: :lower, padding: false]) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(opts)
  end

  def site_id(iso_country_code) do
    Application.get_env(@app, :ebay_site_ids)
    |> Map.get(iso_country_code, 3)
  end

  def prep_headers(token, processed_req_data, site_id \\ site_id(:default)) do
    {:ok,
     [
       {"X-EBAY-API-IAF-TOKEN", token},
       {"X-EBAY-API-COMPATIBILITY-LEVEL", processed_req_data.com_lvl},
       {"X-EBAY-API-CALL-NAME", processed_req_data.call},
       {"X-EBAY-API-SITEID", site_id},
       {"Content-Length", processed_req_data.size}
     ]}
  end

  def get_host(key, provider \\ "EBAY") do
    config = Application.get_env(@app, :ebay_api)

    with host <- Repo.get_by(Host, provider: provider, name: key),
         true <- !is_nil(host) do
      if Keyword.get(config, :production, false), do: host.prod_host, else: host.sandbox_host
    else
      false -> raise "Host not found for #{provider} with #{key}!"
    end
  end

  def get_route(key, provider \\ "EBAY") do
    with route <- Repo.get_by(Route, provider: provider, name: key),
         true <- !is_nil(route) do
      route.url
    else
      false -> raise "Route not found for #{provider} with #{key}!"
    end
  end

  def get_all_global_ids() do
    EbaySiteDetails
    |> select([e], e.global_id)
    |> Repo.all()
  end

  def get_currencies(site_ids) do
    EbaySiteDetails
    |> select([e], %{site_id: e.global_id, currency: e.currency})
    |> where([e], e.global_id in ^site_ids)
    |> Repo.all()
  end

  def get_content_language(key) do
    Repo.get_by(EbaySiteDetails, global_id: key)
    |> wrap_ebay_site_details(:language, "Content Language not found for EBAY with #{key}!")
  end

  def get_currency(key) do
    Repo.get_by(EbaySiteDetails, global_id: key)
    |> wrap_ebay_site_details(:currency, "Content Language not found for EBAY with #{key}!")
  end

  def get_domain(key) do
    EbaySiteDetails
    |> Repo.get_by(global_id: key)
    |> wrap_ebay_site_details(:domain, "Domain not found for EBAY with #{key}!")
    |> then(fn link -> "https://www." <> link end)
  end

  def get_site_id(key) do
    Repo.get_by(EbaySiteDetails, global_id: key)
    |> wrap_ebay_site_details(:site_id, "Site ID not found for EBAY with #{key}!")
  end

  def get_currency_symbol_by_currency(currency) do
    Repo.get_by(EbaySiteDetails, currency: currency)
    |> wrap_ebay_site_details(
      :currency_symbol,
      "Currency Symbol not found for EBAY for #{currency}!"
    )
  end

  def get_ebay_details(key) do
    Repo.get_by(EbaySiteDetails, global_id: key)
    |> wrap_result("EbaySiteDetails")
  end

  defp wrap_ebay_site_details(nil, _key, message), do: raise(message)

  defp wrap_ebay_site_details(site_detail, key, _message), do: Map.get(site_detail, key)

  def map_params(from_data, response_mapping) do
    {:ok,
     response_mapping
     |> Enum.reduce(%{}, fn {k, v}, acc ->
       Map.put(acc, "#{k}", Map.get(from_data, v, nil))
     end)}
  end

  def parse_ebay_categories(resp_map) do
    root_node = Map.get(resp_map, "rootCategoryNode")
    category_acc_map = %{id: nil, name: nil, children: [], level: nil, parent: nil, leaf: nil}

    root_acc_map = %{
      category_acc_map
      | id: get_in(root_node, ["category", "categoryId"]) |> String.to_integer(),
        name: get_in(root_node, ["category", "categoryName"]),
        level: Map.get(root_node, "categoryTreeNodeLevel", 0)
    }

    root_child_nodes = get_in(resp_map, ["rootCategoryNode", "childCategoryTreeNodes"])

    %{
      categories: parse_ebay_categories(root_child_nodes, category_acc_map, root_acc_map),
      provider: "EBAY",
      category_tree_id: Map.get(resp_map, "categoryTreeId"),
      category_tree_version: Map.get(resp_map, "categoryTreeVersion")
    }
  end

  def parse_ebay_categories([], _acc_ref, acc), do: acc

  def parse_ebay_categories(
        [
          %{
            "category" => %{"categoryId" => cId, "categoryName" => cName},
            "categoryTreeNodeLevel" => cLevel,
            "parentCategoryTreeNodeHref" => pHref,
            "leafCategoryTreeNode" => true
          }
          | t
        ],
        acc_ref,
        acc
      ) do
    new_acc_ref = %{
      acc_ref
      | id: cId |> String.to_integer(),
        name: cName,
        level: cLevel,
        leaf: true,
        parent:
          pHref
          |> String.replace(~r/.*=/, "")
          |> String.to_integer()
    }

    {_old, new_acc} =
      Map.get_and_update!(acc, :children, fn old ->
        {old, [new_acc_ref | old] |> Enum.sort(&(&1.name <= &2.name))}
      end)

    parse_ebay_categories(t, acc_ref, new_acc)
  end

  def parse_ebay_categories(
        [
          %{
            "category" => %{"categoryId" => cId, "categoryName" => cName},
            "categoryTreeNodeLevel" => cLevel,
            "parentCategoryTreeNodeHref" => pHref,
            "childCategoryTreeNodes" => chNodes
          }
          | t
        ],
        acc_ref,
        acc
      ) do
    new_children =
      parse_ebay_categories(chNodes, acc_ref, acc_ref)
      |> Map.get(:children)
      |> Enum.sort(&(&1.name <= &2.name))

    new_acc_ref = %{
      acc_ref
      | id: cId |> String.to_integer(),
        name: cName,
        level: cLevel,
        children: new_children,
        leaf: false,
        parent:
          pHref
          |> String.replace(~r/.*=/, "")
          |> String.to_integer()
    }

    {_old, new_acc} =
      Map.get_and_update!(acc, :children, fn old ->
        {old, [new_acc_ref | old] |> Enum.sort(&(&1.name <= &2.name))}
      end)

    parse_ebay_categories(t, acc_ref, new_acc)
  end

  @doc """
  Using this function in production is dangerous!! This is a dev utility function to help with
  easier setup and called on startup of the application
  """
  def create_buckets(bucket_list, region \\ System.get_env("AWS_REGION", "eu-west-2"), opts \\ []) do
    bucket_list
    |> Enum.map(fn bucket ->
      if bucket in get_s3_buckets_list() do
        Logger.info("#{bucket} already available in region #{region}!")
      else
        bucket
        |> S3.put_bucket(region, opts)
        |> ExAws.request!()

        Logger.info("Created #{bucket} in region #{region}!")
      end
    end)
  end

  def get_s3_buckets_list do
    S3.list_buckets()
    |> ExAws.request!()
    |> get_in([:body, :buckets])
    |> Enum.map(fn bucket ->
      bucket.name
    end)
  end

  @doc """
    Generates a put url with given attributes and sets an expiry until which the client
    can directly upload to S3.

    When expires_in is `nil`, it means the url generated is public accessible read_only get url
  """
  def generate_s3_url(map, host \\ "localhost")

  def generate_s3_url(
        %{
          s3_bucket: _bucket,
          s3_path: _path,
          file_size: _size,
          file_name: _name,
          file_type: _type,
          expires_in: expiry,
          type: :put
        },
        _host
      )
      when expiry == nil or expiry == :infinity,
      do:
        {:error,
         "S3 put url should have an expiry for security reasons! Please set a long expiry, if you still wish to continue!"}

  def generate_s3_url(
        %{
          s3_bucket: bucket,
          s3_path: path,
          file_size: size,
          file_name: name,
          file_type: type,
          expires_in: expiry,
          type: :put
        },
        host
      ) do
    s3_upload_path = path <> "/" <> name
    query_params = [{"Content-Type", type}, {"ACL", "public-read"}, {"Content-Length", size}]
    opts = [virtual_host: false, query_params: query_params, expires_in: expiry]

    s3_config =
      if is_nil(host) do
        Config.new(:s3)
      else
        Config.new(:s3, host: host)
      end

    S3.presigned_url(s3_config, :put, bucket, s3_upload_path, opts)
  end

  def generate_s3_url(
        %{
          s3_bucket: bucket,
          s3_path: path,
          file_size: _size,
          file_name: name,
          file_type: _type,
          expires_in: expiry,
          type: :get
        },
        host
      ) do
    s3_upload_path = path <> "/" <> name
    opts = [virtual_host: false, query_params: [], expires_in: expiry]

    s3_config =
      if is_nil(host) do
        Config.new(:s3)
      else
        Config.new(:s3, host: host)
      end

    S3.presigned_url(s3_config, :get, bucket, s3_upload_path, opts)
  end

  def get_image_ext(file_type)
  def get_image_ext("image/jpeg"), do: ".jpg"
  def get_image_ext("image/jpg"), do: ".jpg"
  def get_image_ext("image/png"), do: ".png"
  def get_image_ext("image/tiff"), do: ".tiff"
  def get_image_ext("image/gif"), do: ".gif"
  def get_image_ext("image/webp"), do: ".webp"
  def get_image_ext("image/x-windows-bmp"), do: ".bmp"
  def get_image_ext("image/bmp"), do: ".bmp"
  def get_image_ext("application/octet-stream"), do: ""

  def format_categories(nil, _keys), do: nil
  def format_categories([], _keys), do: nil

  def format_categories(categories, keys) do
    Enum.reduce(categories, [], fn category, acc ->
      acc ++
        [
          %{
            name: Map.get(category, keys[:name]),
            id: Map.get(category, keys[:id]),
            level: Map.get(category, keys[:level]),
            children: format_categories(Map.get(category, keys[:children]), keys),
            parent: Map.get(category, keys[:parent])
          }
        ]
    end)
  end

  def is_empty?(value) when is_nil(value), do: true
  def is_empty?(value) when value == [], do: true
  def is_empty?(value) when value == %{}, do: true
  def is_empty?(""), do: true
  def is_empty?(_), do: false

  def fetch_key_from_map(map, key) when is_bitstring(key) do
    Map.get(map, key, Map.get(map, String.to_atom(key), nil))
  end

  def fetch_key_from_map(map, key) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), nil))
  end

  def add_key_to_map_if_value_exist(map, _key, nil), do: map

  def add_key_to_map_if_value_exist(map, key, value) do
    Map.put(map, key, value)
  end

  def wrap_result(nil, struct_name), do: {:error, "#{struct_name} not found"}
  def wrap_result([], struct_name), do: {:error, "#{struct_name} not found"}
  def wrap_result(records, _struct_name) when is_list(records), do: {:ok, records}
  def wrap_result(record, _struct_name) when is_struct(record), do: {:ok, record}

  def convert_to_float_or_integer(nil), do: 0
  def convert_to_float_or_integer(""), do: 0
  def convert_to_float_or_integer([]), do: 0
  def convert_to_float_or_integer(value) when value == %{}, do: 0
  def convert_to_float_or_integer(value) when is_float(value), do: value
  def convert_to_float_or_integer(value) when is_integer(value), do: value

  def convert_to_float_or_integer(value) when is_bitstring(value) do
    String.to_float(value)
  rescue
    ArgumentError ->
      try do
        String.to_integer(value)
      rescue
        _ -> 0
      end
  end

  def convert_to_float_or_integer(_), do: 0

  def insert_field_if_exist(map, key, value) do
    if is_empty?(value) do
      map
    else
      Map.put(map, key, value)
    end
  end
end
