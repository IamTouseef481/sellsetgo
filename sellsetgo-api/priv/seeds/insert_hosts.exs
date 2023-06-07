defmodule InsertHosts do
  @moduledoc false

  alias SellSetGoApi.Admin.Host
  alias SellSetGoApi.Repo
  require Logger

  def seed do
    app = :sell_set_go_api
    priv_dir = :code.priv_dir(app) |> to_string()
    file_loc = "#{priv_dir}/seeds/hosts.csv"
    Logger.info("Input:File:Hosts: #{file_loc}")

    data =
      file_loc
      |> File.stream!([:raw, :read_ahead, :binary], :line)
      |> Enum.reduce([], fn line, acc ->
        [provider, name, prod_host, sandbox_host] =
          line
          |> String.replace(["\"", "\n"], "")
          |> String.split(",")

        data_map = %{
          provider: provider,
          name: name,
          prod_host: prod_host,
          sandbox_host: sandbox_host,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        Logger.info("Input:Data: #{inspect(data_map)}")
        [data_map | acc]
      end)

    Logger.info("InsertAll:Input:Hosts")

    Repo.insert_all(Host, data,
      on_conflict: [set: [updated_at: DateTime.utc_now()]],
      conflict_target: [:provider, :name]
    )

    Logger.info("InsertedAll:Input:Hosts")
  end
end

InsertHosts.seed()
