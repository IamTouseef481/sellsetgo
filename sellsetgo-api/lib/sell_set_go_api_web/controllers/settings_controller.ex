defmodule SellSetGoApiWeb.SettingsController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.Settings
  alias SellSetGoApi.Accounts.GlobalTemplateTag

  action_fallback SellSetGoApiWeb.FallbackController

  def index_global_info(conn, _params) do
    user_id = SellSetGoApi.get_user_id(conn)
    global_info = Settings.get_global_info(user_id).template_tags
    render(conn, "index.json", data: global_info)
  end

  def update_global_info(conn, attrs) do
    user_id = SellSetGoApi.get_user_id(conn)
    global_info = Settings.get_global_info(user_id)

    with {:ok, %GlobalTemplateTag{template_tags: template_tags}} <-
      Settings.update_global_info(global_info, attrs) do
      render(conn, "index.json", data: template_tags)
    end
  end
end
