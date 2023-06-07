defmodule SellSetGoApiWeb.ErrorView do
  use SellSetGoApiWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  def render("400.json", assigns) do
    %{errors: %{detail: assigns.message}}
  end

  def render("error.json", assigns) do
    %{errors: %{message: assigns.message}}
  end

  def render("ebay_error.json", assigns) do
    %{
      errors: %{
        message: assigns.details["message"],
        longMessage: assigns.details["longMessage"]
      }
    }
  end

  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{message: Phoenix.Controller.status_message_from_template(template)}}
  end
end
