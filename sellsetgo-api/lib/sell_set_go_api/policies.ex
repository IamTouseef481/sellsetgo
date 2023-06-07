defmodule SellSetGoApi.Policies do
  @moduledoc """
  This module contains the policies for the SellSetGoApi.
  """
  @condition_enums %{
    "1000" => "NEW",
    "1500" => "NEW_OTHER",
    "1750" => "NEW_WITH_DEFECTS",
    "2000" => "CERTIFIED_REFURBISHED",
    "2010" => "EXCELLENT_REFURBISHED",
    "2020" => "VERY_GOOD_REFURBISHED",
    "2030" => "GOOD_REFURBISHED",
    "2500" => "SELLER_REFURBISHED",
    "2750" => "LIKE_NEW",
    "3000" => "USED_EXCELLENT",
    "4000" => "USED_VERY_GOOD",
    "5000" => "USED_GOOD",
    "6000" => "USED_ACCEPTABLE",
    "7000" => "FOR_PARTS_OR_NOT_WORKING"
  }

  def process_policies(%{"fulfillmentPolicies" => fulfillment_policies, "total" => total}) do
    fulfillment_policies =
      Enum.map(fulfillment_policies, fn %{"categoryTypes" => category_types} = policy ->
        Map.put(policy, "categoryTypes", Enum.uniq(category_types))
      end)

    %{
      "total" => total,
      "fulfillmentPolicies" => fulfillment_policies
    }
  end

  def process_policies(%{"itemConditionPolicies" => item_condition_policies} = policies) do
    result =
      Enum.map(item_condition_policies, fn policy ->
        Map.put(policy, "itemConditions", add_condition_enum(policy))
      end)

    Map.put(policies, "itemConditionPolicies", result)
  end

  def process_policies(policies) do
    policies
  end

  defp add_condition_enum(%{"itemConditions" => item_conditions}) do
    Enum.map(
      item_conditions,
      &Map.put(&1, "conditionEnum", Map.get(@condition_enums, &1["conditionId"]))
    )
  end
end
