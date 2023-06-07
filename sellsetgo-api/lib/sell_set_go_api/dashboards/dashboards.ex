defmodule SellSetGoApi.Dashboards do
  @moduledoc """
    The Dashboards context
  """

  alias EbayXmlApi.Trading
  alias SellSetGoApi.{EbayXml, Feedbacks, OauthEbay, Repo, Utils}
  alias SellSetGoApi.Offers.Offer
  import Ecto.Query, warn: false

  def get_dashboard_details(marketplace_id, %{user_id: user_id, user_access_token: uat} = csr) do
    tasks =
      Task.async_stream(
        [
          get_stock_count(marketplace_id, user_id),
          get_feedback(csr),
          get_selling_limits(csr),
          get_stock_count_on_ebay(marketplace_id, uat),
          get_violations_summary(csr, marketplace_id)
        ],
        fn task -> task end
      )

    try do
      dashboard =
        Enum.map(tasks, fn {:ok, result} ->
          case result do
            {:error, %{body: %{"errors" => error}}} ->
              {:error, error}
              raise List.first(error)["message"]

            result ->
              result
          end
        end)

      {:ok,
       %{
         stock_count: Enum.at(dashboard, 0),
         feedback: Enum.at(dashboard, 1),
         selling_limits: Enum.at(dashboard, 2),
         stock_count_on_ebay: Enum.at(dashboard, 3),
         violations_summary: Enum.at(dashboard, 4)
       }}
    rescue
      error ->
        case error do
          %RuntimeError{message: message} ->
            {:error, message}

          %BadMapError{} ->
            {:error, "Unable to get dashboard details"}
        end
    end
  end

  def get_stock_count(marketplace_id, user_id) do
    from(o in Offer,
      where:
        o.status == "active" and o.marketplace_id == ^marketplace_id and o.user_id == ^user_id,
      select: %{
        quantity: o.offer_detail["availableQuantity"]
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{quantity: quantity} ->
      cond do
        is_integer(quantity) ->
          %{quantity: quantity}

        is_nil(quantity) ->
          %{quantity: 0}

        is_bitstring(quantity) ->
          %{quantity: String.to_integer(quantity)}
      end
    end)
    |> Enum.reduce(%{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0}, fn %{quantity: quantity}, acc ->
      if quantity < 5 do
        count = Map.get(acc, quantity) + 1
        Map.put(acc, quantity, count)
      else
        acc
      end
    end)
  end

  def get_feedback(csr) do
    with {:ok, %{FeedbackSummary: feedback_summary}} <- Feedbacks.get_feedback(csr, "dashboard") do
      %{
        negative:
          Map.get(feedback_summary, :NegativeFeedbackPeriodArray) |> stitch_feedback_data(),
        neutral: Map.get(feedback_summary, :NeutralFeedbackPeriodArray) |> stitch_feedback_data(),
        positive:
          Map.get(feedback_summary, :PositiveFeedbackPeriodArray) |> stitch_feedback_data(),
        total: Map.get(feedback_summary, :TotalFeedbackPeriodArray) |> stitch_feedback_data()
      }
    end
  end

  def get_selling_limits(csr) do
    with route <- Utils.get_route("privilege"),
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("developer_analytics"),
             csr
           ),
         {:ok, %OAuth2.Response{body: result}} <- OAuth2.Client.get(client, route) do
      %{
        currency: get_in(result, ["sellingLimit", "amount", "currency"]),
        value: get_in(result, ["sellingLimit", "amount", "value"]),
        quantity: get_in(result, ["sellingLimit", "quantity"])
      }
    end
  end

  def get_stock_count_on_ebay(marketplace_id, uat) do
    with processed_req_data <-
           Trading.my_ebay_selling(entries: 5, page_number: 1),
         {:ok, processed_req_hdrs} <-
           Utils.prep_headers(uat, processed_req_data, Utils.get_site_id(marketplace_id)),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         {:ok, %{PaginationResult: %{TotalNumberOfEntries: entries}}} <-
           Trading.get_my_ebay_sell_response(resp.body) do
      %{total_number_of_entries: entries}
    else
      _ -> %{total_number_of_entries: 0}
    end
  end

  def get_violations_summary(csr, marketplace_id) do
    route = Utils.get_route("listing_violation_summary")
    host = Utils.get_host("developer_analytics")
    client = OauthEbay.session_to_client("Bearer", host, csr)

    with {:ok, %OAuth2.Response{body: body}} <-
           OAuth2.Client.get(client, route, [{"X-EBAY-C-MARKETPLACE-ID", marketplace_id}]),
         false <- Utils.is_empty?(body) do
      body["violationSummaries"]
    else
      {:error, %OAuth2.Response{status_code: _code, body: body}} ->
        IO.puts("#{body["error"]}: #{body["error_description"]}")
        []

      true ->
        []
    end
  end

  defp stitch_feedback_data(data) do
    data
    |> Map.get(:FeedbackPeriod)
    |> Enum.reduce(%{}, fn %{PeriodInDays: days, Count: count}, acc ->
      Map.put(acc, "#{days}days", count)
    end)
  end
end
