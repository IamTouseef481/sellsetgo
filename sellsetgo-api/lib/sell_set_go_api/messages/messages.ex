defmodule SellSetGoApi.Messages.Messages do
  @moduledoc false

  alias SellSetGoApi.Accounts.Users
  alias SellSetGoApi.Messages.Message
  alias SellSetGoApi.{LastFetchTime, Repo}
  import Ecto.Query, warn: false

  def form_kw_list(user_id, params) do
    [
      start_time: get_last_fetched_at(user_id).last_fetched_at |> DateTime.to_string(),
      end_time: DateTime.utc_now() |> DateTime.to_string(),
      entries_per_page: params["page_size"] || 50,
      page_number: params["page_no"] || 1
    ]
  end

  def create_or_update_message_fetch_time(user_id, time) do
    %LastFetchTime{}
    |> LastFetchTime.changeset(%{user_id: user_id, last_fetched_at: time, type: "message"})
    |> Repo.insert(
      conflict_target: [:user_id, :type],
      on_conflict: {:replace_all_except, [:id, :inserted_at]}
    )
  end

  def get_last_fetched_at(user_id) do
    from(lft in LastFetchTime)
    |> where([lft], lft.user_id == ^user_id and lft.type == "message")
    |> select([lft], lft.last_fetched_at)
    |> Repo.one()
    |> case do
      nil ->
        {:ok, user} = Users.get_user(user_id)
        %{last_fetched_at: DateTime.from_naive!(user.inserted_at, "Etc/UTC")}

      message_fetch_time ->
        %{last_fetched_at: message_fetch_time}
    end
  end

  def store_messages_in_db(%{MemberMessageExchange: messages}, user_id, kw_list, params) do
    messages = if is_map(messages), do: [messages], else: messages

    message_list =
      Enum.map(messages, fn msg ->
        {:ok, created_date, _zone} = DateTime.from_iso8601("#{msg[:CreationDate]}Z")

        %{
          message_id: "#{get_in(msg, [:Question, :MessageID])}",
          email_json: msg,
          user_id: user_id,
          body: "#{get_in(msg, [:Question, :Body])}",
          subject: "#{get_in(msg, [:Question, :Subject])}",
          sender_id: "#{get_in(msg, [:Question, :SenderID])}",
          created_date: created_date |> DateTime.truncate(:second),
          message_type: "received",
          is_answered: get_in(msg, [:MessageStatus]) == "Answered",
          is_read: false,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)

    Repo.insert_all(Message, message_list,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:message_id]
    )

    messages =
      list_stored_messages_by_user_id(user_id, params)
      |> Enum.group_by(&{&1.sender_id, &1.subject})
      |> Enum.map(fn {_key, value} ->
        Enum.sort_by(value, fn msg -> msg.created_date end, {:asc, DateTime})
      end)
      |> Enum.sort_by(fn value -> List.last(value).created_date end, {:desc, DateTime})

    create_or_update_message_fetch_time(user_id, kw_list[:end_time])

    %{messages: messages, total_no_of_threads: Enum.count(messages)}
  end

  def list_stored_messages_by_user_id(user_id, params) do
    query =
      case params["message_type"] do
        "received" ->
          from(m in Message,
            where: m.user_id == ^user_id and m.message_type == "received",
            order_by: m.created_date
          )

        "sent" ->
          from(m in Message,
            where: m.user_id == ^user_id and m.message_type == "sent",
            order_by: m.created_date
          )

        _ ->
          from(m in Message, where: m.user_id == ^user_id, order_by: m.created_date)
      end

    query |> Repo.paginate(page_size: params["page_size"] || 50, page: params["page_no"] || 1)
  end

  def store_replied_message_in_db(params, user_id) do
    set_is_answered(params["parent_message_id"], user_id)

    attrs = %{
      message_id:
        "reply-#{params["parent_message_id"]}-#{DateTime.utc_now() |> DateTime.to_unix()}",
      parent_id: params["parent_message_id"],
      body: params["body"],
      user_id: user_id,
      subject: params["subject"],
      sender_id: params["recipient_id"],
      created_date: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      message_type: "sent",
      is_read: true,
      is_answered: true,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def set_is_read(%{"id" => id, "is_read" => is_read}, user_id) do
    case Repo.get_by(Message, id: id, user_id: user_id) do
      nil ->
        {:error, "message_not_found"}

      message ->
        message
        |> Message.changeset(%{is_read: is_read})
        |> Repo.update()
    end
  end

  def set_is_answered(message_id, user_id) do
    Repo.get_by(Message, message_id: message_id, user_id: user_id)
    |> Message.changeset(%{is_answered: true})
    |> Repo.update()
  end
end
