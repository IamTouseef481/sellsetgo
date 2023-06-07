defmodule SellSetGoApiWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use SellSetGoApiWeb, :controller
      use SellSetGoApiWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: SellSetGoApiWeb

      import Plug.Conn
      alias SellSetGoApiWeb.Router.Helpers, as: Routes

      # https://elixirforum.com/t/generate-csrf-token-send-it-to-frontend-put-token-in-header-in-following-request-not-working/41094/6
      # https://elixirforum.com/t/csrf-and-postman/12910 (WORKING SOLUTION)
      # def set_csrf_token(conn, _opts) do
      #   delete_csrf_token()
      #   csrf_token = get_csrf_token()
      #   unmasked_csrf_token = Process.get(:plug_unmasked_csrf_token)

      #   conn
      #   |> put_session("_csrf_token", unmasked_csrf_token)
      #   |> put_resp_header("x-csrf-token", csrf_token)
      # end
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/sell_set_go_api_web/templates",
        namespace: SellSetGoApiWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      def render("message.json", %{message: message}) do
        %{data: message}
      end

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp view_helpers do
    quote do
      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import SellSetGoApiWeb.ErrorHelpers
      alias SellSetGoApiWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
