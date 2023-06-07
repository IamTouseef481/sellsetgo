defmodule SellSetGoApiWeb.DescriptionTemplateController do
  use SellSetGoApiWeb, :controller

  alias SellSetGoApi.Template
  alias SellSetGoApi.Accounts.DescriptionTemplate

  action_fallback SellSetGoApiWeb.FallbackController

  def index(conn, _params) do
    user_id = SellSetGoApi.get_user_id(conn)
    description_templates = Template.list_description_templates(user_id)
    render(conn, "index.json", data: description_templates)
  end

  def create(conn, attrs) do
    user_id = SellSetGoApi.get_user_id(conn)
    attrs = Map.put(attrs, "user_id", user_id)

    with {:ok, %DescriptionTemplate{} = description_template} <-
      Template.create_description_template(attrs) do
      conn
      |> put_status(:created)
      |> render("index.json", data: description_template)
    end
  end

  def show(conn, %{"id" => id}) do
    user_id = SellSetGoApi.get_user_id(conn)

    with %DescriptionTemplate{} = description_template <-
      Template.get_description_template!(id, user_id) do
      render(conn, "index.json", data: description_template)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user_id = SellSetGoApi.get_user_id(conn)
    description_template = Template.get_description_template!(id, user_id)
    attrs = params
      |> Map.delete("id")
      |> Map.put("user_id", user_id)

    with {:ok, %DescriptionTemplate{} = updated_description_template} <-
      Template.update_description_template(description_template, attrs) do
      render(conn, "index.json", data: updated_description_template)
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = SellSetGoApi.get_user_id(conn)
    description_template = Template.get_description_template!(id, user_id)

    with {:ok, %DescriptionTemplate{}} <-
      Template.delete_description_template(description_template) do
      send_resp(conn, :no_content, "")
    end
  end
end
