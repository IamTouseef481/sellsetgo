defmodule SellSetGoApi.Template do
  @moduledoc """
  The Template context.
  """

  import Ecto.Query, warn: false
  alias SellSetGoApi.Repo

  alias SellSetGoApi.Accounts.DescriptionTemplate

  @doc """
  Returns the list of description templates.

  ## Examples

      iex> list_description_templates("testUser")
      [%DescriptionTemplate{}, ...]

  """
  def list_description_templates(user_id) do
    DescriptionTemplate
    |> where(user_id: ^user_id)
    |> select([u], %{id: u.id, name: u.name, inserted_at: u.inserted_at, updated_at: u.updated_at})
    |> Repo.all()
  end

  @doc """
  Gets a single description template.

  Returns tuple with error message if the description template does not exist.

  ## Examples

      iex> get_description_template!(123, "testUser")
      %DescriptionTemplate{}

      iex> get_description_template!(456, "testUser")
      {:error, :not_found, "Description Template Not Found"}

  """
  def get_description_template!(id, user_id) do
    try do
      DescriptionTemplate
      |> Repo.get_by!(id: id, user_id: user_id)
    rescue
      _e in [Ecto.NoResultsError, Ecto.Query.CastError] ->
        {:error, :not_found, "Description Template Not Found"}
    end
  end
  @doc """
  Creates a description template.

  ## Examples

      iex> create_description_template(%{field: value})
      {:ok, %DescriptionTemplate{}}

      iex> create_description_template(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_description_template(attrs) do
    %DescriptionTemplate{}
    |> DescriptionTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a description template.

  ## Examples

      iex> update_description_template(description_template, %{field: new_value})
      {:ok, %DescriptionTemplate{}}

      iex> update_description_template(description_template, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_description_template(%DescriptionTemplate{} = description_template, attrs) do
    description_template
    |> DescriptionTemplate.changeset(attrs)
    |> Repo.update()
  end

  def update_description_template({:error, _, _}, _) do
    {:error, :unprocessable_entity, "Description Template Not Found"}
  end
  @doc """
  Deletes a description template.

  ## Examples

      iex> delete_description_template(description_template)
      {:ok, %DescriptionTemplate{}}

      iex> delete_description_template(description_template)
      {:error, %Ecto.Changeset{}}

  """
  def delete_description_template(%DescriptionTemplate{} = description_template) do
    Repo.delete(description_template)
  end

  def delete_description_template({:error, _, _}) do
    {:error, :unprocessable_entity, "Description Template Not Found"}
  end
end
