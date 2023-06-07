defmodule SellSetGoApi do
  @moduledoc """
  SellSetGoApi keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Retrieves the current user ID associated with a given connection.
  """
  def get_user_id(conn), do: conn.assigns.current_session_record.user_id

  def get_session(conn), do: conn.assigns.current_session_record

  def get_global_id(conn), do: conn.assigns.current_session_record.user.site

  def get_access_token(conn), do: conn.assigns.current_session_record.user_access_token
end
