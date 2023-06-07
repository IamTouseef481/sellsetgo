defmodule InsertRoutes do
  @moduledoc false

  alias SellSetGoApi.Admin.Route
  alias SellSetGoApi.Repo
  require Logger

  def seed do
    app = :sell_set_go_api
    priv_dir = :code.priv_dir(app) |> to_string()
    file_loc = "#{priv_dir}/seeds/routes.csv"
    Logger.info("Input:File:Routes: #{file_loc}")

    data =
      file_loc
      |> File.stream!([:raw, :read_ahead, :binary], :line)
      |> Enum.reduce([], fn line, acc ->
        [provider, name, url] =
          line
          |> String.replace(["\"", "\n"], "")
          |> String.split(",")

        data_map = %{
          provider: provider,
          name: name,
          url: url,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        Logger.info("Input:Data: #{inspect(data_map)}")
        [data_map | acc]
      end)

    Logger.info("InsertAll:Input:Routes")

    Repo.insert_all(Route, data,
      on_conflict: [set: [updated_at: DateTime.utc_now()]],
      conflict_target: [:provider, :name]
    )

    Logger.info("InsertedAll:Input:Routes")
  end
end

InsertRoutes.seed()
