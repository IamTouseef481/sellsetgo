defmodule SellSetGoApi.IntegrationsTest do
  use SellSetGoApi.DataCase

  alias SellSetGoApi.Integrations

  describe "big_commerce_sessions" do
    alias SellSetGoApi.Integrations.BigCommerceSession

    @valid_attrs %{access_token: "some access_token", other_params: %{}}
    @update_attrs %{access_token: "some updated access_token", other_params: %{}}
    @invalid_attrs %{access_token: nil, other_params: nil}

    def big_commerce_session_fixture(attrs \\ %{}) do
      {:ok, big_commerce_session} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Integrations.create_big_commerce_session()

      big_commerce_session
    end

    test "list_big_commerce_sessions/0 returns all big_commerce_sessions" do
      big_commerce_session = big_commerce_session_fixture()
      assert Integrations.list_big_commerce_sessions() == [big_commerce_session]
    end

    test "get_big_commerce_session!/1 returns the big_commerce_session with given id" do
      big_commerce_session = big_commerce_session_fixture()

      assert Integrations.get_big_commerce_session!(big_commerce_session.id) ==
               big_commerce_session
    end

    test "create_big_commerce_session/1 with valid data creates a big_commerce_session" do
      assert {:ok, %BigCommerceSession{} = big_commerce_session} =
               Integrations.create_big_commerce_session(@valid_attrs)

      assert big_commerce_session.access_token == "some access_token"
      assert big_commerce_session.other_params == %{}
    end

    test "create_big_commerce_session/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Integrations.create_big_commerce_session(@invalid_attrs)
    end

    test "update_big_commerce_session/2 with valid data updates the big_commerce_session" do
      big_commerce_session = big_commerce_session_fixture()

      assert {:ok, %BigCommerceSession{} = big_commerce_session} =
               Integrations.update_big_commerce_session(big_commerce_session, @update_attrs)

      assert big_commerce_session.access_token == "some updated access_token"
      assert big_commerce_session.other_params == %{}
    end

    test "update_big_commerce_session/2 with invalid data returns error changeset" do
      big_commerce_session = big_commerce_session_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Integrations.update_big_commerce_session(big_commerce_session, @invalid_attrs)

      assert big_commerce_session ==
               Integrations.get_big_commerce_session!(big_commerce_session.id)
    end

    test "delete_big_commerce_session/1 deletes the big_commerce_session" do
      big_commerce_session = big_commerce_session_fixture()

      assert {:ok, %BigCommerceSession{}} =
               Integrations.delete_big_commerce_session(big_commerce_session)

      assert_raise Ecto.NoResultsError, fn ->
        Integrations.get_big_commerce_session!(big_commerce_session.id)
      end
    end

    test "change_big_commerce_session/1 returns a big_commerce_session changeset" do
      big_commerce_session = big_commerce_session_fixture()
      assert %Ecto.Changeset{} = Integrations.change_big_commerce_session(big_commerce_session)
    end
  end
end
