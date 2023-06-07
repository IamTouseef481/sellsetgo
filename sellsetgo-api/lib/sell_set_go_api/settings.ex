defmodule SellSetGoApi.Settings do
  @moduledoc """
  The Settings context.
  """

  import Ecto.Query, warn: false
  alias SellSetGoApi.Repo

  alias SellSetGoApi.Accounts.GlobalTemplateTag

  @doc """
  Gets a single global info because there is only one global info for the user.

  Returns tuple with error message if the global info does not exist.

  ## Examples

      iex> get_global_info("testUser")
      [%GlobalTemplateTag.Tag{}, ...]

      iex> get_global_info("testUser")
      {:error, :not_found, "Global Info Not Found"}

  """
  def get_global_info(user_id) do
    try do
      GlobalTemplateTag
      |> Repo.get_by!(user_id: user_id)
    rescue
      _e in [Ecto.NoResultsError, Ecto.Query.CastError] ->
        {:error, :not_found, "Global Info Not Found"}
    end
  end

  @doc """
  Updates a global info.

  ## Examples

      iex> update_global_info(global_info, %{field: new_value})
      {:ok, %GlobalTemplateTag{}}

      iex> update_global_info(global_info, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_global_info(%GlobalTemplateTag{} = global_info, attrs) do
    global_info
    |> GlobalTemplateTag.changeset(attrs)
    |> Repo.update()
  end

  def update_global_info({:error, _, _}, _) do
    {:error, :unprocessable_entity, "Global Info Not Found"}
  end
end
