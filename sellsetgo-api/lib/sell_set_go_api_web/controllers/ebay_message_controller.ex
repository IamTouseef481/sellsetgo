defmodule SellSetGoApiWeb.EbayMessageController do
  @moduledoc """
    This module contains the common functions to process Messages.
  """
  use SellSetGoApiWeb, :controller
  alias EbayXmlApi.Message
  alias SellSetGoApi.{EbayXml, Utils}
  alias SellSetGoApi.Messages.Messages
  action_fallback(SellSetGoApiWeb.FallbackController)

  def index(%{assigns: %{current_session_record: current_session_record}} = conn, params) do
    kw_list = Messages.form_kw_list(current_session_record.user_id, params)
    processed_req_data = Message.get_member_messages(kw_list)

    with {:ok, processed_req_hdrs} <-
           Utils.prep_headers(current_session_record.user_access_token, processed_req_data),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         {:ok, resp_struct} <-
           Message.get_member_messages_response(resp.body),
         messages <-
           Messages.store_messages_in_db(
             resp_struct,
             current_session_record.user_id,
             kw_list,
             params
           ) do
      conn
      |> render("index.json", result: messages)
    else
      {:error, _} -> {:error, "Error while fetching messages from Ebay"}
    end
  end

  def update(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "is_read"} = params
      ) do
    with {:ok, message} <- Messages.set_is_read(params, user_id) do
      conn
      |> render("index.json", result: message)
    end
  end

  def reply(%{assigns: %{current_session_record: current_session_record}} = conn, params) do
    kw_list = [
      parent_message_id: params["parent_message_id"],
      body: params["body"],
      recipient_id: params["recipient_id"]
    ]

    processed_req_data = Message.get_reply_messages(kw_list)

    with {:ok, processed_req_hdrs} <-
           Utils.prep_headers(current_session_record.user_access_token, processed_req_data),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         {:ok, %{Ack: "Success"}} <-
           Message.get_reply_messages_response(resp.body),
         {:ok, replied_message} <-
           Messages.store_replied_message_in_db(params, current_session_record.user_id) do
      conn
      |> render("index.json", result: replied_message)
    else
      {:ok, %{Ack: "Failure"} = response} ->
        message = get_in(response, [:Errors, :LongMessage])

        conn
        |> render("index.json", result: message)
    end
  end
end
