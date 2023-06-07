defmodule InsertEbaySiteDetails do
  @moduledoc false

  alias SellSetGoApi.Admin.EbaySiteDetails
  alias SellSetGoApi.Repo
  require Logger

  def seed do
    app = :sell_set_go_api
    priv_dir = :code.priv_dir(app) |> to_string()
    file_loc = "#{priv_dir}/seeds/ebay_site_details.csv"
    Logger.info("Input:File:EbaySiteDetails: #{file_loc}")

    data =
      file_loc
      |> File.stream!([:raw, :read_ahead, :binary], :line)
      |> Enum.reduce([], fn line, acc ->
        [site_id, global_id, language, territory, name, status, currency, domain, currency_symbol] =
          line
          |> String.replace(["\"", "\n"], "")
          |> String.split(",")

        {site_id, _any} = Integer.parse(site_id)

        data_map = %{
          site_id: site_id,
          global_id: global_id,
          language: language,
          territory: territory,
          name: name,
          status: status,
          currency: currency,
          domain: domain,
          currency_symbol: currency_symbol,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        Logger.info("Input:Data: #{inspect(data_map)}")
        [data_map | acc]
      end)

    Logger.info("InsertAll:Input:EbaySiteDetails")

    Repo.insert_all(EbaySiteDetails, data,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:site_id, :global_id]
    )

    Logger.info("InsertedAll:Input:EbaySiteDetails")
  end
end

InsertEbaySiteDetails.seed()
