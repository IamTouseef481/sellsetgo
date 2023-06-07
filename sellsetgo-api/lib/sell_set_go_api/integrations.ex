defmodule SellSetGoApi.Integrations do
  @moduledoc """
  The Ecommerce Integrations context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias SellSetGoApi.Integrations.{BigCommerce, BigCommerceSession}
  alias SellSetGoApi.Repo

  def create_big_commerce_integration(attrs \\ %{}) do
    %BigCommerce{}
    |> BigCommerce.changeset(attrs)
    |> Repo.insert()
  end

  def update_big_commerce_integration(big_commerce_integration, attrs \\ %{}) do
    big_commerce_integration
    |> BigCommerce.changeset(attrs)
    |> Repo.update()
  end

  def get_big_commerce_integration_using_store_hash(store_hash) do
    from(bc in BigCommerce,
      where: like(bc.store_url, ^"%#{store_hash}%"),
      select: bc
    )
    |> Repo.one!()
  end

  def get_big_commerce_integration_by(filters) do
    case Repo.get_by(BigCommerce, filters) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  def link_big_commerce(big_commerce_integration, big_commerce_session_attrs) do
    Multi.new()
    |> Multi.update(
      :big_commerce_integration,
      BigCommerce.changeset(big_commerce_integration, %{active: true})
    )
    |> Multi.insert(
      :big_commerce_session,
      BigCommerceSession.changeset(%BigCommerceSession{}, big_commerce_session_attrs)
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{big_commerce_integration: _bc_int, big_commerce_session: _bc_session}} ->
        {:ok, :success}

      {:error, _op, res, _others} ->
        {:error, res}
    end
  end

  def unlink_big_commerce(big_commerce_integration) do
    Multi.new()
    |> Multi.update(
      :big_commerce_integration,
      BigCommerce.changeset(big_commerce_integration, %{active: false})
    )
    |> Multi.delete_all(
      :big_commerce_session,
      fn %{big_commerce_integration: bc_config} ->
        from(s in BigCommerceSession, where: s.user_id == ^bc_config.user_id)
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{big_commerce_integration: _bc_int, big_commerce_session: _bc_session}} ->
        {:ok, :success}

      {:error, _op, res, _others} ->
        {:error, res}
    end
  end

  def construct_big_commerce_session_attrs(%OAuth2.AccessToken{} = token, bc_config) do
    {:ok,
     Map.new()
     |> Map.put("access_token", token.access_token)
     |> Map.put("other_params", token.other_params)
     |> Map.put("user_id", bc_config.user_id)}
  end

  @doc """
  Gets a single big_commerce_session.

  Raises `Ecto.NoResultsError` if the Big commerce session does not exist.

  ## Examples

      iex> get_big_commerce_session!(123)
      %BigCommerceSession{}

      iex> get_big_commerce_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_big_commerce_session!(id), do: Repo.get!(BigCommerceSession, id)

  @doc """
  Creates a big_commerce_session.

  ## Examples

      iex> create_big_commerce_session(%{field: value})
      {:ok, %BigCommerceSession{}}

      iex> create_big_commerce_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_big_commerce_session(attrs \\ %{}) do
    %BigCommerceSession{}
    |> BigCommerceSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a big_commerce_session.

  ## Examples

      iex> delete_big_commerce_session(big_commerce_session)
      {:ok, %BigCommerceSession{}}

      iex> delete_big_commerce_session(big_commerce_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_big_commerce_session(%BigCommerceSession{} = big_commerce_session) do
    Repo.delete(big_commerce_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking big_commerce_session changes.

  ## Examples

      iex> change_big_commerce_session(big_commerce_session)
      %Ecto.Changeset{data: %BigCommerceSession{}}

  """
  def change_big_commerce_session(%BigCommerceSession{} = big_commerce_session, attrs \\ %{}) do
    BigCommerceSession.changeset(big_commerce_session, attrs)
  end
end
