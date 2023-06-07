defmodule SellSetGoApi.UpdateSaleQty do
  @moduledoc """
  The UpdateSaleQty context.
  """
  alias SellSetGoApi.Offers.Offer
  alias SellSetGoApi.Inventory.Product
  alias SellSetGoApi.Repo
  alias SellSetGoApi.Accounts.User
  import Ecto.Query, warn: false

  @doc """
  This function takes a username as input and returns the corresponding user ID.
  If the username does not exist in the system, the function returns an error message.

  ## Examples

      iex> get_userid_by_username("test")
      {:ok, 12345}
  """
  def get_userid_by_username(username) do
    user_id = User
      |> select([u], u.id)
      |> where(username: ^username)
      |> Repo.one
    case user_id do
      nil -> {:error, :not_found, "User name changed! Once login on SSG"}
      user_id -> {:ok, user_id}
    end
  end

  @doc """
  This function updates the quantity for a specific product SKU associated with a given user ID in Products table.

  ## Examples

      iex> update_sale_quantity_on_products(1234, "test1", 5)
      {:ok, %Product{}}
  """
  def update_sale_quantity_on_products(user_id, sku, quantity_purchased) do
    product = Product
      |> Repo.get_by(user_id: user_id, sku: sku)
    case product do
      nil -> {:error, :not_found, "This product not listed on SSG"}
      product ->
        updated_qty = product.quantity - quantity_purchased
        cond do
          updated_qty < 0 -> {:error, :bad_request, "Negative Quantity"}
          true ->
            product
            |> Product.changeset(%{quantity: updated_qty})
            |> Repo.update()
        end
    end
  end

  @doc """
  This function updates the quantity for a specific product SKU associated with a given user ID in Offers table.

  ## Examples

      iex> update_sale_quantity_on_offers(1234, "test1", 5)
      {:ok, %Offer{}}
  """
  def update_sale_quantity_on_offers(user_id, sku, updated_qty) do
    offer = Offer
      |> Repo.get_by(user_id: user_id, sku: sku)
    offer_detail = Map.put(offer.offer_detail, "availableQuantity", updated_qty)
    offer
    |> Offer.changeset(%{offer_detail: offer_detail})
    |> Repo.update()
  end

end
