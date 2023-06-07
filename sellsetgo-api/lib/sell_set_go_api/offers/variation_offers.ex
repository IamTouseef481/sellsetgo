defmodule SellSetGoApi.Offers.VariationOffers do
  @moduledoc """
  This module contains the API for the Sell Set Go Inventory Products API.
  """

  alias SellSetGoApi.Offers.VariationOffer
  alias SellSetGoApi.Repo
  import Ecto.Query, warn: false

  def create_offers(offers, user_id, parent_sku) do
    offer_params = Enum.map(offers, &form_offer_params(&1, user_id, parent_sku))

    if VariationOffer.changeset_valid_for_all?(%VariationOffer{}, offer_params) do
      Repo.insert_all(VariationOffer, offer_params,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at, :is_submitted, :offer_id]}
      )

      {:ok, offer_params}
    else
      {:error, "Invalid data"}
    end
  end

  def create_offers(offers) do
    if VariationOffer.changeset_valid_for_all?(%VariationOffer{}, offers) do
      Repo.insert_all(VariationOffer, offers,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at, :is_submitted, :offer_id]}
      )

      {:ok, offers}
    else
      {:error, "Invalid data"}
    end
  end

  def get_ebay_not_submitted(skus, %{user_id: user_id}) do
    from(vo in VariationOffer,
      where:
        vo.user_id == ^user_id and vo.sku in ^skus and fragment("? IS NOT TRUE", vo.is_submitted),
      select: vo.sku
    )
    |> Repo.all()
  end

  def get_offer_ids(skus, %{user_id: user_id}) do
    from(vo in VariationOffer,
      where: vo.user_id == ^user_id and vo.sku in ^skus,
      select: %{sku: vo.sku, offer_id: vo.offer_id}
    )
    |> Repo.all()
  end

  def update_offers(offers) do
    if VariationOffer.changeset_valid_for_all?(%VariationOffer{}, offers) do
      Repo.insert_all(VariationOffer, offers,
        conflict_target: [:sku, :user_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

      {:ok, offers}
    else
      {:error, "Invalid data"}
    end
  end

  defp form_offer_params(offer, user_id, parent_sku) do
    %{
      sku: offer["sku"],
      user_id: user_id,
      offer_detail: offer,
      marketplace_id: offer["marketplace_id"],
      status: "draft",
      parent_sku: parent_sku,
      is_submitted: false,
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }
  end

  def get_variations_by_parent(parent_sku, user_id) do
    VariationOffer
    |> where([vo], vo.parent_sku == ^parent_sku and vo.user_id == ^user_id)
    |> Repo.all()
  end
end
