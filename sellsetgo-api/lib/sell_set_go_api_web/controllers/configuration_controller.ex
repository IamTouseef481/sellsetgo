defmodule SellSetGoApiWeb.ConfigurationController do
  use SellSetGoApiWeb, :controller

  alias SellSetGoApi.Accounts.{DescriptionTemplate, GlobalTemplateTag}
  alias SellSetGoApi.Configurations

  action_fallback(SellSetGoApiWeb.FallbackController)

  def create(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "templates"} = params
      ) do
    params = Map.put(params, "user_id", user_id)

    case Configurations.create_description_templates(params) do
      {:ok, description_template} ->
        conn
        |> render("tags.json", tags: description_template)

      error ->
        error
    end
  end

  def index(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "tags"}
      ) do
    conn
    |> render("tags.json",
      tags: Configurations.get_global_template_tags(user_id).template_tags
    )
  end

  def index(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "templates", "list" => "name"}
      ) do
    conn
    |> render("tags.json", tags: Configurations.list_description_template_names(user_id))
  end

  def index(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "templates"}
      ) do
    conn
    |> render("tags.json", tags: Configurations.list_description_templates(user_id))
  end

  def update(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "templates"} = params
      ) do
    params = Map.put(params, "user_id", user_id)

    case Configurations.update_description_templates(params) do
      {:ok, description_template} ->
        conn
        |> render("tags.json", tags: description_template)

      error ->
        error
    end
  end

  def update(
        %{assigns: %{current_session_record: %{user_id: user_id}}} = conn,
        %{"type" => "tags"} = params
      ) do
    tags = Configurations.get_global_template_tags(user_id)

    with {:ok, %GlobalTemplateTag{} = tags} <-
           Configurations.update_global_template_tags(tags, params) do
      render(conn, "tags.json", tags: tags.template_tags)
    end
  end

  def delete(%{assigns: %{current_session_record: %{user_id: user_id}}} = conn, %{
        "id" => id,
        "type" => "templates"
      }) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %DescriptionTemplate{} = description_template <-
           Configurations.get_description_template(%{id: id, user_id: user_id}),
         {:ok, %DescriptionTemplate{}} <-
           Configurations.delete_description_template(description_template) do
      render(conn, "message.json", message: "Successfully deleted description template")
    else
      _ -> {:error, "Incorrect HTML template id."}
    end
  end
end
