defmodule SellSetGoApi.Repo do
  use Ecto.Repo,
    otp_app: :sell_set_go_api,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 20
end
