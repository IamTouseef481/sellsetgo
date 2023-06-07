defmodule SellSetGoApi.Accounts.Users do
  @moduledoc """
  The Accounts.Users context.
  """

  import Ecto.Query, warn: false
  alias SellSetGoApi.{Repo, Utils}
  alias SellSetGoApi.Accounts.{StoreCategory, User}
  alias EbayXmlApi.XmlUtils

  def response_mapping do
    [
      id: "userId",
      username: "username",
      email: "email",
      site: "registrationMarketplaceId",
      account_type: "accountType"
    ]
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    raise "TODO"
  end

  @doc """
  Gets a single user.

  Raises if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

  """
  def get_user(id) do
    Repo.get_by(User, id: id)
    |> Utils.wrap_result(__MODULE__)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, ...}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert(
      conflict_target: :id,
      on_conflict: {:replace_all_except, [:id, :inserted_at, :profile_details]}
    )
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, ...}

  """
  def update_user(%User{} = user, attrs) do
    User.changeset(user, attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, ...}

  """
  def delete_user(%User{} = _user) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Todo{...}

  """
  def change_user(%User{} = _user, _attrs \\ %{}) do
    raise "TODO"
  end

  def show_store_categories(user_id) do
    query = from(sc in StoreCategory, where: sc.user_id == ^user_id)

    case Repo.all(query) do
      nil ->
        []

      store_categories ->
        store_categories
    end
  end

  def insert_ebay_store_categories(%{CustomCategories: %{CustomCategory: nil}}, _user_id),
    do: {:error, :no_categories_provided}

  def insert_ebay_store_categories(%{CustomCategories: %{CustomCategory: []}}, _user_id),
    do: {:error, :no_categories_provided}

  def insert_ebay_store_categories(
        %{CustomCategories: %{CustomCategory: categories}, Name: name},
        user_id
      ) do
    category = %{custom_category: parsing_store_categories(categories)}

    %StoreCategory{}
    |> StoreCategory.changeset(%{categories: category, user_id: user_id, store_name: name})
    |> Repo.insert_or_update(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:store_name, :user_id]
    )
  end

  def get_store_category(%{id: id}), do: Repo.get_by(StoreCategory, id: id)

  def form_inventory_locations(%{"locations" => locations}) do
    Enum.reduce(locations, [], fn location = %{"location" => %{"address" => address}}, acc ->
      address = get_address(address)

      acc ++
        [
          %{
            city: address.city,
            name: location["name"],
            postal_code: address.postal_code,
            merchant_location_key: location["merchantLocationKey"],
            country: address.country
          }
        ]
    end)
  end

  def form_inventory_locations(_), do: []

  defp parsing_store_categories(categories, parent_id \\ nil)
  defp parsing_store_categories([], _parent_id), do: []
  defp parsing_store_categories(nil, _parent_id), do: []

  defp parsing_store_categories(categories, parent_id) do
    categories = if is_map(categories), do: [categories], else: categories

    Enum.reduce(categories, [], fn category, acc ->
      category_id = Map.get(category, :CategoryID)

      acc ++
        [
          %{
            name: Map.get(category, :Name),
            category_id: category_id,
            leaf_node: is_nil(Map.get(category, :ChildCategory, nil)),
            order: Map.get(category, :Order),
            child_categories:
              parsing_store_categories(
                Map.get(category, :ChildCategory, []),
                category_id
              ),
            parent_id: parent_id
          }
        ]
    end)
  end

  defp get_address(address) do
    %{
      city: Map.get(address, "city"),
      postal_code: Map.get(address, "postalCode"),
      country: Map.get(address, "country")
    }
  end

  def extract_email_from_xml_api_response(response) do
    XmlUtils.parse_xml_to_map(response, :naive)
    |> get_in([:GetUserResponse, :User, :Email])
  end
end
