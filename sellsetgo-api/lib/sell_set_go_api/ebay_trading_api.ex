defmodule SellSetGoApi.EbayTradingApi do
  @moduledoc """
  The EbayTradingApi context for all Ebay Api calls.
  """
  import Ecto.Query, warn: false
  alias SellSetGoApi.Repo
  alias SellSetGoApi.Admin.EbaySiteDetails

  @api_endpoint Application.get_env(:sell_set_go_api, :ebay_endpoints)[:trading_api]

  @doc """
  Constructs and returns a list of headers required for making an eBay API request.

  ## Parameters

  - `site_id` (integer): The numeric ID of the eBay site where the API request will be made.
  - `request_name` (string): The name of the eBay API call being made.
  - `access_token` (string): The access token required for authentication with the eBay API.
  """
  def ebay_request_headers(site_id, request_name, access_token) do
    [
      {"X-EBAY-API-SITEID", site_id},
      {"X-EBAY-API-COMPATIBILITY-LEVEL", 967},
      {"X-EBAY-API-CALL-NAME", request_name},
      {"X-EBAY-API-IAF-TOKEN", access_token}
    ]
  end

  @doc """
  Constructs and returns the eBay API request body for the update sku request.

  ## Parameters

  - `item_id` (string): The ID of the item.

  - `sku` (string): The SKU (Stock Keeping Unit) of the item.
  """
  def ebay_update_sku_request_body(item_id, sku) do
    """
    <?xml version="1.0" encoding="utf-8"?>
    <ReviseFixedPriceItemRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <ErrorLanguage>en_US</ErrorLanguage>
      <Item>
        <ItemID>#{item_id}</ItemID>
        <SKU>#{sku}</SKU>
      </Item>
    </ReviseFixedPriceItemRequest>
    """
  end

  @doc """
  Constructs and returns the eBay API request body for the get feedback request.
  """
  def ebay_get_feedback_request_body() do
    """
    <?xml version="1.0" encoding="utf-8"?>
    <GetFeedbackRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <ErrorLanguage>en_US</ErrorLanguage>
    </GetFeedbackRequest>
    """
  end

  @doc """
  Retrieves the site ID associated with the given global ID.

  ## Examples

      iex> get_site_id_from_global_id("EBAY-US")
      0

  ## Parameters

  - `global_id` (string): The global ID for which the site ID should be retrieved.

  ## Return Value

  The site ID (integer) associated with the given global ID.

  """
  def get_site_id_from_global_id(global_id) do
    EbaySiteDetails
    |> select([u], u.site_id)
    |> where(global_id: ^global_id)
    |> Repo.one()
  end

  @doc """
  Construct eBay api request using the provided request body and headers.

  ## Parameters

  - `body` (string): The request body containing the update information in XML format.
  - `headers` (list): The headers required for the API request.
  - `request_name` (string): The name of the request.
  """
  def ebay_api_request(body, headers, request_name) do
    api_request = @api_endpoint
    |> HTTPoison.post(body, headers)
    |> xml_to_map()

    case request_name do
      "GetFeedback" -> validate_feedback(api_request)
      "ReviseFixedPriceItem" -> validate(api_request, "Sku Updated")
      _ -> []
    end
  end

  @doc """
  Converts XML response body to a map representation.

  ## Examples

      iex> xml_to_map({:ok, %HTTPoison.Response{body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Result>Success</Result></Response>", status_code: 200}})
      %{"Response" => %{"Result" => "Success"}}

  ## Parameters

  - `{:ok, response}` (tuple): A tuple containing the HTTP response with a successful status code (200) and the XML response body.

  ## Return Value

  A map representation of the XML response body.

  """
  def xml_to_map({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body
    |> XmlJson.Parker.deserialize()
  end

  @doc """
  Validates the response body and returns an error message if the Ack value is "Failure". Returns a success message if the Ack value is 'Warning'.

  ## Examples

      iex> validate({:ok, %{"Ack" => "Failure", "Errors" => [{"ShortMessage" => "Invalid input"}, {"ShortMessage" => "Missing required field"}]}}, _message)
      {:error, 400, "Invalid input Missing required field"}

      iex> validate({:ok, %{"Ack" => "Warning"}}, message)
      {:ok, "SKU Updated"}

      iex> validate({:ok, %{"Ack" => "Success"}}, message)
      {:ok, "SKU Updated"}

  ## Parameters

  - `{:ok, body}` (tuple): A tuple containing the successful response body, represented as a map. The body should have an `"Ack"` field.

  ## Return Value

  If the `"Ack"` field is `"Failure"` and the `"Errors"` field is a list, it concatenates the `"ShortMessage"` values from each error map and returns an error tuple `{:error, 400, message}` with an HTTP status code of 400 and the concatenated error message. If the `"Ack"` field is `"Failure"` and the `"Errors"` field is not a list, it returns an error tuple `{:error, 400, errors["ShortMessage"]}` with an HTTP status code of 400 and the error message from the single error map. If the `"Ack"` field is `"Warning"`, it returns a success tuple `{:ok, "SKU Updated"}` indicating the successful update.

  """
  def validate({:ok, %{"Ack" => "Failure", "Errors" => errors}}, _message) do
    case is_list(errors) do
      true ->
        message = errors
        |> Enum.reduce("", fn error, acc -> acc <> error["ShortMessage"] end)
        {:error, 400, message}
      false ->
        {:error, 400, errors["ShortMessage"]}
    end
  end

  def validate({:ok, %{"Ack" => "Success"}}, message), do: {:ok, message}

  def validate({:ok, %{"Ack" => "Warning"}}, message), do: {:ok, message}

  @doc """
  Validates the feedback response body and returns the feedback data if applicable.

  ## Examples

      iex> validate_feedback({:ok, %{"Ack" => "Success", "FeedbackSummary" => feedback_summary}})
      {:ok, feedback_data}

      iex> validate_feedback({:ok, %{"Ack" => "Failure"}})
      {:ok, []}

  ## Parameters

  - `{:ok, body}` (tuple): A tuple containing the successful feedback response body.

  ## Return Value

  If successful, returns `{:ok, feedback_data}` where `feedback_data` is a map of feedback counts. Otherwise, returns `{:ok, []}`.

  """
  def validate_feedback({:ok, %{"Ack" => "Success", "FeedbackSummary" => feedback_summary}}) do
    feedback_data = Map.new(
      nagative: Map.get(feedback_summary, "NegativeFeedbackPeriodArray") |> iterate_feedback(),
      positive: Map.get(feedback_summary, "PositiveFeedbackPeriodArray") |> iterate_feedback(),
      neutral: Map.get(feedback_summary, "NeutralFeedbackPeriodArray") |> iterate_feedback(),
      total: Map.get(feedback_summary, "TotalFeedbackPeriodArray") |> iterate_feedback()
    )
    {:ok, feedback_data}
  end

  def validate_feedback({:ok, %{"Ack" => "Failure"}}), do: {:ok, []}

  @doc """
  Iterates over the feedback data and constructs a map of feedback counts based on the period in days.

  ## Examples

      iex> iterate_feedback([%{"PeriodInDays" => 1, "Count" => 5}, %{"PeriodInDays" => 7, "Count" => 10}])
      %{"1days" => 5, "7days" => 10}

  ## Parameters

  - `feedbacks` (list): A list of feedback data.

  ## Return Value

  A map of feedback counts based on the period in days.

  """
  def iterate_feedback(feedbacks) do
    Enum.reduce(feedbacks, %{},
      fn %{"PeriodInDays" => days, "Count" => count}, acc ->
        Map.put(acc, "#{days}days", count)
      end
    )
  end
end
