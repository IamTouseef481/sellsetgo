defmodule SellSetGoApi.Admin do
  @moduledoc false

  require Logger
  import Ecto.Query, warn: false

  alias SellSetGoApi.Admin.Category
  alias SellSetGoApi.{OauthEbay, Repo, Utils}
  def insert_ebay_categories(site_codes \\ ["EBAY_GB"])

  def insert_ebay_categories(site_codes) when site_codes != nil and site_codes != [] do
    host = Utils.get_host("commerce_taxonomy")
    {:ok, client} = OauthEbay.get_application_access_token()
    new_client = client |> Map.put(:site, host)

    site_codes
    |> Enum.each(fn site_id ->
      c_stime = DateTime.utc_now()

      with def_tree_route <-
             Utils.get_route("get_default_category_tree_id") <> "?marketplace_id=#{site_id}",
           {:ok, %OAuth2.Response{} = data} <- OAuth2.Client.get(new_client, def_tree_route),
           def_category_id <- Map.get(data.body, "categoryTreeId"),
           categories_route <-
             Utils.get_route("get_category_tree") <> "/#{def_category_id}",
           {:ok, %OAuth2.Response{} = new_data} <-
             OAuth2.Client.get(new_client, categories_route) do
        c_etime = DateTime.utc_now()
        c_time = DateTime.diff(c_etime, c_stime)

        Logger.info(
          "Default Category Tree Id and All Categories for Ebay #{site_id} fetched in #{c_time} seconds"
        )

        pc_stime = DateTime.utc_now()
        categories_map = Utils.parse_ebay_categories(new_data.body)

        %Category{}
        |> Category.changeset(categories_map)
        |> Repo.insert_or_update(
          on_conflict: :replace_all,
          conflict_target: [:provider, :category_tree_id]
        )

        pc_etime = DateTime.utc_now()
        pc_time = DateTime.diff(pc_etime, pc_stime)

        Logger.info(
          "All Categories parsing and seeding for Ebay #{site_id} completed in #{pc_time} seconds"
        )
      end
    end)
  end

  def insert_ebay_categories(_), do: insert_ebay_categories()

  def show_admin_categories(marketplace_id) do
    category_tree_id = Utils.get_site_id(marketplace_id)

    case Repo.get_by(Category, provider: "EBAY", category_tree_id: "#{category_tree_id}") do
      nil ->
        %{}

      admin_categories ->
        admin_categories
    end
  end
end
