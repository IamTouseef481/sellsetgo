defmodule SellSetGoApiWeb.PolicyController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.{OauthEbay, Policies, Utils}

  action_fallback(SellSetGoApiWeb.FallbackController)

  def index(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "marketplace_id" => marketplace_id,
          "policy_type" => policy_type,
          "type" => "policy_list"
        }
      ) do
    with route <-
           Utils.get_route("get_policy") <> "/#{policy_type}?marketplace_id=#{marketplace_id}",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("sell_account"),
             current_session_record
           ),
         {:ok, %OAuth2.Response{body: policies}} <- OAuth2.Client.get(client, route) do
      conn
      |> render("policy_index.json", policy_lists: Policies.process_policies(policies))
    end
  end

  def index(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{
          "marketplace_id" => marketplace_id,
          "category_ids" => category_ids
        }
      )
      when is_binary(category_ids) do
    category_ids = String.replace(category_ids, ",", "|")

    with route <-
           Utils.get_route("get_item_condition_policies") <>
             "/#{marketplace_id}" <>
             "/get_item_condition_policies?filter=categoryIds:{#{category_ids}}",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("sell_account"),
             current_session_record
           ),
         {:ok, %OAuth2.Response{body: policies}} <- OAuth2.Client.get(client, route) do
      conn
      |> render("policy_index.json", policy_lists: Policies.process_policies(policies))
    else
      {:error, %OAuth2.Error{reason: :nxdomain}} ->
        {:error, %{key: :nxdomain, destination: "unable to reach ebay servers!"}}

      {:error, error} ->
        {:error, error}
    end
  end
end
