use Mix.Config

if File.exists?("config/ebay_creds.exs") do
  import_config "ebay_creds.exs"
end

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :sell_set_go_api, SellSetGoApi.Repo,
  username: "dzine-hub",
  password: "dzinehub@123",
  hostname: "storage",
  database: "sell_set_go_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sell_set_go_api, SellSetGoApiWeb.Endpoint,
  http: [port: 4002],
  server: false

config :sell_set_go_api, :environment, :test
# Print only warnings and errors during test
config :logger, level: :warn
