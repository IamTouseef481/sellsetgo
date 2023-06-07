defmodule SellSetGoApi.Inventory.BigCommerceInvertory.BigCommerce do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :type, Ecto.Enum, values: [:physical, :digital], default: :physical
    field :weight, :float
    field :price, :float
    field :sku, :string
    field :description, :string
    field :inventory_level, :float
    field :condition, :string
    field :images, {:array, :map}
  end

  @fields ~w(name type weight price sku description inventory_level condition images)a
  @required_fields ~w(name type weight price)a

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def parse_params(params) do
    attrs = %{
      name: bc_title(params),
      type: "physical",
      weight: bc_weight(params),
      price: bc_price(params),
      sku: sku(params),
      description: bc_descp(params),
      inventory_level: bc_inventory_level(params),
      condition: "New",
      images: bc_images(params)
    }

    case changeset(attrs) do
      %Ecto.Changeset{valid?: true} ->
        {:ok, attrs}

      %Ecto.Changeset{valid?: false} ->
        {:error, :invalid_params_passed}
    end
  end

  defp bc_title(%{"inventory" => %{"product" => %{"bc_fields" => bc_field}}}),
    do: Map.get(bc_field, "title")

  defp bc_descp(%{"inventory" => %{"product" => %{"bc_fields" => bc_field}}}),
    do: Map.get(bc_field, "description")

  defp bc_price(%{"inventory" => %{"product" => %{"bc_fields" => bc_field}}}),
    do: Map.get(bc_field, "price")

  defp bc_weight(%{"inventory" => %{"product" => %{"bc_fields" => bc_field}}}),
    do: Map.get(bc_field, "weight", 1.0)

  defp bc_inventory_level(%{"inventory" => %{"product" => %{"bc_fields" => bc_field}}}),
    do: Map.get(bc_field, "inventory_level", 0)

  defp sku(%{"inventory" => %{"product" => %{"bc_fields" => bc_field}}, "sku" => sku}),
    do: Map.get(bc_field, "sku", sku)

  defp bc_images(%{"images" => images}), do: images || []
end
