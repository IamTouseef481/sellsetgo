use Mix.Config

config :sell_set_go_api, :ebay_oauth2_scopes,
  scope:
    "https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/sell.marketing https://api.ebay.com/oauth/api_scope/sell.inventory https://api.ebay.com/oauth/api_scope/sell.account https://api.ebay.com/oauth/api_scope/sell.fulfillment https://api.ebay.com/oauth/api_scope/sell.analytics.readonly https://api.ebay.com/oauth/api_scope/sell.finances https://api.ebay.com/oauth/api_scope/sell.payment.dispute https://api.ebay.com/oauth/api_scope/commerce.identity.readonly https://api.ebay.com/oauth/api_scope/commerce.notification.subscription",
  # The below scopes work only in sandbox
  # scope:
  # "https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/buy.order.readonly https://api.ebay.com/oauth/api_scope/buy.guest.order https://api.ebay.com/oauth/api_scope/sell.marketing https://api.ebay.com/oauth/api_scope/sell.inventory https://api.ebay.com/oauth/api_scope/sell.account https://api.ebay.com/oauth/api_scope/sell.fulfillment https://api.ebay.com/oauth/api_scope/sell.analytics.readonly https://api.ebay.com/oauth/api_scope/sell.marketplace.insights.readonly https://api.ebay.com/oauth/api_scope/commerce.catalog.readonly https://api.ebay.com/oauth/api_scope/buy.shopping.cart https://api.ebay.com/oauth/api_scope/buy.offer.auction https://api.ebay.com/oauth/api_scope/commerce.identity.readonly https://api.ebay.com/oauth/api_scope/commerce.identity.email.readonly https://api.ebay.com/oauth/api_scope/commerce.identity.phone.readonly https://api.ebay.com/oauth/api_scope/commerce.identity.address.readonly https://api.ebay.com/oauth/api_scope/commerce.identity.name.readonly https://api.ebay.com/oauth/api_scope/commerce.identity.status.readonly https://api.ebay.com/oauth/api_scope/sell.finances https://api.ebay.com/oauth/api_scope/sell.item.draft https://api.ebay.com/oauth/api_scope/sell.payment.dispute https://api.ebay.com/oauth/api_scope/sell.item https://api.ebay.com/oauth/api_scope/sell.reputation https://api.ebay.com/oauth/api_scope/commerce.notification.subscription",
  ccg_scope: "https://api.ebay.com/oauth/api_scope"

config :sell_set_go_api, :ebay_oauth2_client,
  strategy: OAuth2.Strategy.AuthCode,
  client_id: "dZine-Hu-f453-42a1-b7da-5b1d19fe2a20",
  client_secret: "0fda245b-62c9-409a-9504-96c493828a9a",
  redirect_uri: "dZine-Hub_Pvt_L-dZine-Hu-f453-4-gkqtircci",
  site: "https://auth.ebay.com",
  authorize_url: "/oauth2/authorize",
  token_url: "https://api.ebay.com/identity/v1/oauth2/token"

config :sell_set_go_api, :ebay_api,
  site: "https://api.ebay.com",
  url: "/ws/api.dll",
  dev_name: "9a9d9e68-7bc9-4225-8217-921ec032ed1c",
  # If production is false, app will automatically use sandbox urls
  production: true

# This configuration sets the Ebay Api endpoints
config :sell_set_go_api, :ebay_endpoints,
  inventory_location: "https://api.ebay.com/sell/inventory/v1/location",
  trading_api: "https://api.ebay.com/ws/api.dll",
  category_tree: "https://api.ebay.com/commerce/taxonomy/v1/category_tree"
