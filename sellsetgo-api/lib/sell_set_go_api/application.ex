defmodule SellSetGoApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias SellSetGoApi.Utils
  use Application

  def start(_type, _args) do
    IO.puts(elixirexperts_logo())

    if Mix.env() == :dev do
      Utils.create_buckets(
        ["#{Mix.env()}-ebay-sellers-listing-images", "#{Mix.env()}-ebay-seller-reports"],
        "eu-west-2",
        acl: :public_read
      )
    end

    children = [
      # Start the Ecto repository
      SellSetGoApi.Repo,
      # Start the Telemetry supervisor
      SellSetGoApiWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: SellSetGoApi.PubSub},
      # Start the Endpoint (http/https)
      SellSetGoApiWeb.Endpoint
      # Start a worker by calling: SellSetGoApi.Worker.start_link(arg)
      # {SellSetGoApi.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SellSetGoApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SellSetGoApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp emit_app_env do
    env =
      Application.get_env(:sell_set_go_api, :environment, :not_set)
      |> to_string()
      |> String.upcase()

    IO.ANSI.blink_slow() <>
      IO.ANSI.white_background() <>
      IO.ANSI.red() <> IO.ANSI.bright() <> " " <> env <> " " <> IO.ANSI.reset()
  end

  defp elixirexperts_logo do
    elixir_version_info = System.build_info()
    node_name = Node.self() |> to_string()

    """
    +----------------------+--------------------------------------+
    #{build_key_value("Node Name", node_name)}
    #{build_key_value("Elixir Version", elixir_version_info[:build])}
    #{build_key_value("Elixir VCS Revision", elixir_version_info[:revision])}
    #{build_key_value("ERTS Version", "#{:erlang.system_info(:version)}")}
    #{build_key_value("System Architecture", "#{:erlang.system_info(:system_architecture)}")}
    #{build_key_value("CPU Cores for ERTS",
    "#{:erlang.system_info(:logical_processors_available)}")}
    #{build_key_value("Author", "elixirexperts.com")}
    #{build_key_value("Email", "<expert@elixirexperts.com>")}
    #{build_key_value("Website", "https://elixirexperts.com>")}
    +----------------------+--------------------------------------+

         █▀▀ █   ▀█▀ █ █ ▀█▀ █▀▄ █▀▀ █ █ █▀█ █▀▀ █▀▄ ▀█▀ █▀▀
         █▀▀ █    █  ▄▀▄  █  █▀▄ █▀▀ ▄▀▄ █▀▀ █▀▀ █▀▄  █  ▀▀█
         ▀▀▀ ▀▀▀ ▀▀▀ ▀ ▀ ▀▀▀ ▀ ▀ ▀▀▀ ▀ ▀ ▀   ▀▀▀ ▀ ▀  ▀  ▀▀▀

    Starting Application in #{emit_app_env()} environment.
    """
  end

  defp build_key_value(key, value) do
    "| #{String.pad_trailing(key, 20)} | #{String.pad_trailing(value, 36)} |"
  end
end
