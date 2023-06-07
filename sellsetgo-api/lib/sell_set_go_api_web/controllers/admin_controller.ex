defmodule SellSetGoApiWeb.AdminController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.Admin

  def create(conn, %{"marketplace_ids" => marketplace_ids}) do
    with :ok <- Admin.insert_ebay_categories(marketplace_ids) do
      conn
      |> put_status(200)
      |> render("message.json", message: "Ebay categories fetched successfully")
    end
  end

  def create(conn, _params), do: create(conn, %{"marketplace_ids" => nil})
end
