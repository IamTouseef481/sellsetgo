defmodule SellSetGoApi.Reports do
  @moduledoc """
    This module is responsible for handling the reports.
  """
  alias ExAws.S3
  alias SellSetGoApi.{Configurations, Repo, Report, Utils}
  alias SellSetGoApi.Inventory.Product
  alias SellSetGoApi.Offers.Offer
  import(Ecto.Query, warn: false)

  @offer_detail_fields [
    "categoryId",
    "price",
    "returnPolicyId",
    "paymentPolicyId",
    "fulfillmentPolicyId",
    "listingDescription",
    "descriptionTemplate",
    "ebayCategoryNames",
    "storeCategoryNames"
  ]

  def get_offer_reports(%{"marketplace_id" => marketplace_id} = params, user_id) do
    from(o in Offer)
    |> where(
      [o],
      o.user_id == ^user_id and o.marketplace_id == ^marketplace_id and o.status == "active"
    )
    |> build_query(params)
    |> Repo.all()
    |> select_output_fields(params, user_id)
    |> Utils.wrap_result(__MODULE__)
  end

  def get_product_offer_reports(%{"marketplace_id" => marketplace_id} = params, user_id) do
    results =
      from(o in Offer)
      |> where(
        [o],
        o.user_id == ^user_id and o.marketplace_id == ^marketplace_id and
          o.status == "active"
      )
      |> join(:inner, [o], p in Product, on: p.sku == o.sku and p.user_id == o.user_id)
      |> select([o, p], %{
        listing_id: o.listing_id,
        offer_detail: o.offer_detail,
        offer_id: o.offer_id,
        sku: o.sku,
        marketplace_id: o.marketplace_id,
        title: p.title,
        condition: p.condition,
        inserted_at: o.inserted_at,
        updated_at: o.updated_at
      })
      |> build_query(params)
      |> Repo.all()
      |> select_output_fields(params, user_id)

    if(results in [[], nil]) do
      {:error, "Reports not found"}
    else
      Utils.wrap_result(results, __MODULE__)
    end
  end

  def export_item_specifics_report(aspects, user_id, marketplace_id, category_id) do
    report =
      from(p in Product,
        where: p.user_id == ^user_id and p.status == "active",
        join: o in Offer,
        on: p.sku == o.sku and p.user_id == o.user_id,
        where:
          o.offer_detail["categoryId"] == ^category_id and o.marketplace_id == ^marketplace_id,
        select: %{
          sku: p.sku,
          title: p.title,
          marketplace_id: o.marketplace_id,
          item_id: o.listing_id,
          aspects: p.aspects
        }
      )
      |> Repo.all()
      |> Enum.map(fn %{
                       sku: sku,
                       title: title,
                       marketplace_id: marketplace_id,
                       item_id: item_id,
                       aspects: aspect
                     } ->
        custom_aspect = aspect["custom"]

        custom_aspect_val =
          if Utils.is_empty?(custom_aspect), do: "", else: Jason.encode!(custom_aspect)

        %{
          "Sku" => sku,
          "Title" => title,
          "MarketplaceId" => marketplace_id,
          "ItemId" => item_id,
          "custom" => custom_aspect_val
        }
        |> Map.merge(merge_dynamic_value(aspect["dynamic"]))
      end)

    master_map =
      Enum.reduce(
        aspects,
        %{"Sku" => "", "Title" => "", "MarketplaceId" => "", "ItemId" => ""},
        fn %{required: required, usage: usage, name: name}, acc ->
          val = if required, do: "Required", else: usage
          Map.put(acc, name, val)
        end
      )

    headers =
      ["Sku", "Title", "MarketplaceId", "ItemId"] ++
        Enum.map(aspects, fn %{name: name} -> name end) ++ ["custom"]

    type = "item_specifics"
    file_name = type <> "_#{category_id}_#{DateTime.utc_now() |> DateTime.to_unix()}.csv"

    ([master_map] ++ report)
    |> Stream.map(fn map ->
      map
    end)
    |> CSV.encode(headers: headers)
    |> Stream.into(File.stream!(file_name, [:write, :utf8]))
    |> Stream.run()

    upload_to_s3(file_name, type, user_id)
  end

  def export_product_offer_reports(reports, type, user_id) do
    file_name = type <> "_#{DateTime.utc_now() |> DateTime.to_unix()}.csv"

    reports
    |> encode_export_reports()
    |> Stream.into(File.stream!(file_name, [:write, :utf8]))
    |> Stream.run()

    upload_to_s3(file_name, type, user_id)
  end

  def upload_to_s3(file_name, type, user_id) do
    bucket_name = System.get_env("REPORTS_BUCKET", "dev-ebay-seller-reports")

    aws_response =
      bucket_name
      |> S3.put_object("#{user_id}/#{file_name}", File.read!(file_name))
      |> ExAws.request()

    with {:ok, _body} <- aws_response,
         {:ok, _report} <- insert_into_db(file_name, user_id, type) do
      File.rm_rf!(file_name)
      {:ok, file_name}
    else
      {:error, {_, _, _}} ->
        {:error, "AWS S3 error"}

      error ->
        error
    end
  end

  def insert_into_db(file_name, user_id, type) do
    %Report{}
    |> Report.changeset(%{
      file_name: file_name,
      user_id: user_id,
      type: type
    })
    |> Repo.insert()
  end

  def list_reports(params, user_id) do
    count = params["count"]

    try do
      {:ok,
       if Utils.is_empty?(count) do
         from(r in Report, where: r.user_id == ^user_id, order_by: [desc: :inserted_at])
       else
         from(r in Report,
           where: r.user_id == ^user_id,
           order_by: [desc: :inserted_at],
           limit: ^count
         )
       end
       |> Repo.all()}
    rescue
      error -> {:error, "Enter a valid integer for count: instead of '#{error.value}'"}
    end
  end

  def get_all_aspects_for_category_id(""), do: []

  def get_all_aspects_for_category_id(%{"aspects" => aspects}) do
    Enum.map(aspects, fn %{
                           "aspectConstraint" => %{
                             "aspectRequired" => required,
                             "aspectUsage" => usage
                           },
                           "localizedAspectName" => name
                         } ->
      %{
        required: required,
        usage: usage,
        name: name
      }
    end)
  end

  def get_all_aspects_for_category_id(_), do: []

  defp merge_dynamic_value(value) do
    if Utils.is_empty?(value) do
      %{}
    else
      Enum.reduce(value, %{}, fn {name, value}, acc ->
        Map.put(acc, name, get_string_from_value(value))
      end)
    end
  end

  defp build_query(query, %{"start_date" => st_date, "end_date" => end_date}) do
    query
    |> where([o], o.inserted_at >= ^st_date and o.inserted_at <= ^end_date)
  end

  defp build_query(query, %{"start_date" => st_date}) do
    query
    |> where([o], o.inserted_at >= ^st_date)
  end

  defp build_query(query, %{"end_date" => end_date}) do
    query
    |> where([o], o.inserted_at <= ^end_date)
  end

  defp build_query(query, _params), do: query

  defp select_output_fields(list, %{"output_field" => []}, _user_id) do
    list
    |> Enum.map(fn %{sku: sku, listing_id: listing_id} -> %{sku: sku, listing_id: listing_id} end)
  end

  defp select_output_fields(list, %{"output_field" => output_field}, user_id) do
    description_templates =
      if Enum.any?(output_field, fn field -> field == "descriptionTemplate" end) do
        Configurations.list_description_templates(user_id)
      else
        []
      end

    list
    |> Enum.map(fn map ->
      Enum.reduce(output_field, %{}, fn field, acc ->
        Map.put(acc, field, get_field_value(map, field, description_templates))
      end)
    end)
  end

  defp select_output_fields(list, _params, _user_id) do
    list
    |> Enum.map(fn %{sku: sku, listing_id: listing_id} -> %{sku: sku, listing_id: listing_id} end)
  end

  defp get_field_value(%{offer_detail: offer_detail}, field, description_templates)
       when field in @offer_detail_fields do
    cond do
      field in ["returnPolicyId", "paymentPolicyId", "fulfillmentPolicyId"] ->
        get_in(offer_detail, ["listingPolicies", field])

      field in ["categoryId", "listingDescription"] ->
        get_in(offer_detail, [field])

      field in ["storeCategoryNames", "ebayCategoryNames"] ->
        offer_detail
        |> Map.get(field, [])
        |> Enum.map_join(", ", & &1)

      field == "price" ->
        get_in(offer_detail, ["pricingSummary", "price", "value"])

      field == "descriptionTemplate" ->
        find_description_name(offer_detail, description_templates)

      true ->
        ""
    end
  end

  defp get_field_value(map, field, _description_templates) do
    Map.get(map, :"#{field}")
  end

  defp find_description_name(offer_detail, description_templates) do
    case Enum.find(description_templates, fn template ->
           template.id == offer_detail["listingDescriptionTemplateId"]
         end) do
      nil ->
        ""

      template ->
        template.name
    end
  end

  defp encode_export_reports(reports) do
    reports
    |> Stream.map(fn report ->
      report
    end)
    |> CSV.encode(headers: List.first(reports) |> Enum.map(fn {key, _val} -> key end))
  end

  defp get_string_from_value(value) when is_list(value) do
    Enum.reduce(value, "", fn string, acc ->
      acc <> "," <> string
    end)
    |> String.trim_leading(",")
  end

  defp get_string_from_value(value) when is_bitstring(value), do: value
end
