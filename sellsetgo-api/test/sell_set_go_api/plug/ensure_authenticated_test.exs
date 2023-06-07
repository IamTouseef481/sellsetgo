defmodule SellSetGoApi.Plug.EnsureAuthenticatedTest do
  use SellSetGoApi.DataCase

  alias SellSetGoApi.Plug.EnsureAuthenticated

  # setup %{conn: conn} do
  #   {:ok, conn: put_req_header(conn, "accept", "application/json")}
  # end

  describe "EnsureAuthenticatedPlug - Unit Tests" do
    test "get session from database - No Session Found" do
      assert EnsureAuthenticated.get_db_session(nil) == {:error, :unauthenticated}
    end
  end
end
