defmodule SellSetGoApi.Feedbacks do
  @moduledoc """
    The Feedback context
  """

  alias EbayXmlApi.Dashboard
  alias SellSetGoApi.Accounts.Users
  alias SellSetGoApi.{EbayXml, Feedback, Repo, Utils}

  import Ecto.Query, only: [where: 3]

  def get_feedback(%{user_access_token: uat, user_id: user_id}, type) do
    with {:ok, user} <- Users.get_user(user_id),
         processed_req_data <- get_feedback_process_request(type, user),
         {:ok, processed_req_hdrs} <-
           Utils.prep_headers(uat, processed_req_data),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs) do
      Dashboard.get_feedback_response(resp.body)
    end
  end

  defp get_feedback_process_request(type, user) do
    case type do
      "dashboard" ->
        Dashboard.get_feedback(UserID: user.username)

      "feedback" ->
        Dashboard.get_feedback(
          UserID: user.username,
          CommentType: "Positive",
          DetailLevel: "ReturnAll"
        )
    end
  end

  def delete_feedbacks_for_user(user_id) do
    Feedback |> where([fb], fb.user_id == ^user_id) |> Repo.delete_all()
  end

  def insert_feedbacks(feedbacks, user_id) do
    Enum.map(feedbacks, fn feedback ->
      {:ok, comment_time} = feedback[:CommentTime] |> DateTime.from_naive("Etc/UTC")

      %{
        comment_text: feedback[:CommentText],
        item_title: feedback[:ItemTitle],
        item_id: feedback[:ItemID] |> to_string(),
        commenting_user_id: feedback[:CommentingUser],
        commenting_user_score: feedback[:CommentingUserScore],
        feedback_rating_star: feedback[:FeedbackRatingStar],
        price: feedback[:ItemPrice] |> to_string(),
        currency_symbol:
          feedback[:currencyID] |> to_string() |> Utils.get_currency_symbol_by_currency(),
        comment_time: comment_time |> DateTime.truncate(:second),
        user_id: user_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
    |> then(fn feedbacks ->
      Repo.insert_all(Feedback, feedbacks)
    end)
  end

  def list_feedbacks(user_id) do
    Feedback |> where([fb], fb.user_id == ^user_id) |> Repo.all()
  end

  def store_feedback_in_db(csr) do
    with {:ok, %{FeedbackDetailArray: %{FeedbackDetail: feedbacks}}} <-
           get_feedback(csr, "feedback"),
         feedbacks <- Enum.take(feedbacks, 10),
         {:delete, {_, nil}} <- delete_feedbacks_for_user(csr.user_id),
         {count, nil} <- insert_feedbacks(feedbacks, csr.user_id) do
      {:ok, "#{count} feedback/s inserted"}
    else
      {:ok, %{FeedbackDetailArray: %{}}} ->
        {:ok, "No Feedbacks found"}

      {:delete, {_, _}} ->
        {:error, "Something went wrong in deleting the feedbacks"}

      {_, _} ->
        {:error, "Something went wrong in inserting feedbacks"}
    end
  end
end
