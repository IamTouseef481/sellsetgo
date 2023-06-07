# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :sell_set_go_api,
  ecto_repos: [SellSetGoApi.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :sell_set_go_api, SellSetGoApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "YXBr0fVZTr5FmonDvydfQ5BfPLZhtp9S5xojzoj3arkcIb78VD4q/BHJ3bl5EgRP",
  render_errors: [view: SellSetGoApiWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: SellSetGoApi.PubSub,
  live_view: [signing_salt: "OoydaApI"]

# Deleted Session options from Endpoint.ex file
config :phoenix, SellSetGoApiWeb.Router,
  session: [
    store: :cookie,
    key: "_ssg_key",
    signing_salt: "5lPCI6t2AlaQH8mNJEoxE3SWWvk=",
    secure: true,
    same_site: "None",
    sign: true,
    encryption_salt: "C4CaMhXMxiC9b/O6wnZvJ3zXRLae2IVAk4TN0qiDDzs=",
    # 10 days cookie valid
    max_age: 864_000
  ]

# Reference https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/types/SiteCodeType.html
config :sell_set_go_api,
  ebay_site_ids: %{
    "AT" => 16,
    "AU" => 15,
    "BEFR" => 23,
    "BENL" => 123,
    "CA" => 2,
    "CAFR" => 210,
    "CH" => 193,
    "DE" => 77,
    "ES" => 186,
    "FR" => 71,
    "HK" => 201,
    "IE" => 205,
    "IN" => 203,
    "IT" => 101,
    "MY" => 207,
    "NL" => 146,
    "PH" => 211,
    "PL" => 212,
    "RU" => 215,
    "SG" => 216,
    "UK" => 3,
    "US" => 0
  }

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :cors_plug,
  origin: [
    "https://localhost:3000",
    "http://localhost:3000",
    "http://localhost",
    "https://localhost"
  ],
  max_age: 86400

config :tesla, adapter: Tesla.Adapter.Hackney

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
