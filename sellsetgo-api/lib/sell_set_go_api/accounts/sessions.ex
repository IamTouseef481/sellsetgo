defmodule SellSetGoApi.Accounts.Sessions do
  @moduledoc """
  The Accounts.Sessions context.
  """

  import Ecto.Query, warn: false
  alias SellSetGoApi.Repo

  alias SellSetGoApi.Accounts.Session

  def construct_expiration(dt \\ DateTime.utc_now(), seconds) do
    dt |> DateTime.add(seconds, :second)
  end

  def construct_session_attrs(%OAuth2.AccessToken{} = token) do
    {:ok,
     Map.new()
     |> Map.put("last_refreshed_at", DateTime.utc_now())
     |> Map.put("refresh_token", token.refresh_token)
     |> Map.put(
       "refresh_token_expires_at",
       construct_expiration(Map.get(token.other_params, "refresh_token_expires_in"))
     )
     |> Map.put("user_access_token", token.access_token)
     |> Map.put(
       "user_access_token_expires_at",
       DateTime.from_unix!(token.expires_at)
     )}
  end

  @doc """
  Returns the list of sessions.

  ## Examples

      iex> list_sessions()
      [%Session{}, ...]

  """
  def list_sessions do
    raise "TODO"
  end

  @doc """
  Gets a single session.

  Raises if the Session does not exist.

  ## Examples

      iex> get_session!(123)
      %Session{}

  """
  def get_session(id), do: {:ok, Repo.get(Session, id) |> Repo.preload(:user)}

  @doc """
  Updates a session.

  ## Examples

      iex> update_session(session, %{field: new_value})
      {:ok, %Session{}}

      iex> update_session(session, %{field: bad_value})
      {:error, ...}

  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end
end
