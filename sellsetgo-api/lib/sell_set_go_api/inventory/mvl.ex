defmodule SellSetGoApi.Inventory.Mvl do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "mvl" do
    field(:parent, :map)
    field(:variation_products, {:array, :map})
    field(:variation_offers, {:array, :map})
  end

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(mvl_item, _options) do
      """
        {"parent": #{Jason.encode!(mvl_item.parent)},"variation_products": #{Jason.encode!(mvl_item.variation_products)},"variation_offers": #{Jason.encode!(mvl_item.variation_offers)}}
      """
    end
  end
end
