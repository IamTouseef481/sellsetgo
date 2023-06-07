use Mix.Config

config :sell_set_go_api, :big_commerce_oauth2_scopes,
  scope: "store_v2_products users_basic_information"

config :sell_set_go_api, :big_commerce_oauth2_client,
  strategy: OAuth2.Strategy.AuthCode,
  client_id: "i05ft5q4xk46zqsgsn1ng198bwisifq",
  client_secret: "4801934f1105aef8a66f99df6ec21884036f1b0377380fc132b02e540e09cc8e",
  redirect_uri: "https://localhost/api/integrations/bc/new",
  site: "https://login.bigcommerce.com",
  authorize_url: "/oauth2/authorize",
  token_url: "/oauth2/token"
