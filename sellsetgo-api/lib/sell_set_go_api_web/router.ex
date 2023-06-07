defmodule SellSetGoApiWeb.Router do
  use SellSetGoApiWeb, :router

  pipeline :api do
    plug(Plug.Session, Application.get_env(:phoenix, __MODULE__)[:session])
    plug(:fetch_session)
    plug(:put_secure_browser_headers)
  end

  pipeline :XML do
    plug(SellSetGoApi.Plug.FetchXml)
  end

  pipeline :JSON do
    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Phoenix.json_library()

    plug(:accepts, ["json"])
  end

  pipeline :authenticated do
    plug(SellSetGoApi.Plug.EnsureAuthenticated)
  end

  scope "/api/webhook", SellSetGoApiWeb do
    pipe_through([:api, :XML])
    post("/", NotificationController, :webhook)
  end

  scope "/api/public", SellSetGoApiWeb do
    pipe_through([:api, :JSON])

    resources("/sessions", SessionController, only: [:new])
    get("/sessions", SessionController, :create)
    resources("/integrations/bc", BigCommerceIntegrationController, only: [:new])
    put("/update-sale-qty/:username", UpdateSaleQtyController, :update)
  end

  scope "/api", SellSetGoApiWeb do
    pipe_through([:api, :authenticated, :JSON])

    resources("/description-templates", DescriptionTemplateController)
    resources("/inventory-locations", InventoryLocationController, param: "merchantLocationKey")
    scope("/settings") do
      get("/global-info", SettingsController, :index_global_info)
      put("/global-info", SettingsController, :update_global_info, singleton: true)
    end
    scope("/images") do
      get("/media-library", ImageController, :index)
    end
    put("/update-sku/:id", EbayTradingApiController, :update)
    get("/dashboard", MiscController, :dashboard)

    resources("/sessions", SessionController, only: [:show, :delete], singleton: true)
    resources("/images/upload", ImageController, only: [:create, :new])
    resources("/common", EbayCommonController, only: [:index])
    post("/opt_in", EbayCommonController, :opt_in)
    get("/opted_in", EbayCommonController, :opted_in)
    post("/translate", EbayCommonController, :translate)
    resources("/user", UserController, only: [:index, :create])

    resources("/user", UserController, only: [:update, :delete], singleton: true) do
      get("/fetch_feedbacks", UserController, :fetch_feedbacks)
    end

    get("/store_categories", UserController, :get_store_categories)

    scope("/reports") do
      post("/", UserController, :export_reports)
      get("/", UserController, :download_reports)
      get("/list", UserController, :list_reports)
    end

    resources("/configurations", ConfigurationController,
      only: [:create, :update, :delete],
      singleton: true
    )

    put("/bulk-update", InventoryController, :bulk_update)

    get("/configurations", ConfigurationController, :index)
    # get("/dashboard", EbayCommonController, :dashboard)

    resources("/policy", PolicyController, only: [:index])
    resources("/items", ItemController, only: [:index])
    post("/profile", UserController, :save_profile_details)
    put("/profile", UserController, :update_profile_details)
    get("/profile", UserController, :get_profile_details)
    get("/item", ItemController, :get_quantity_sold)
    post("/csv", InventoryController, :bulk_create_from_csv)

    resources("/offers", OfferController, only: [:create, :show, :update], singleton: true) do
      post("/publish", OfferController, :publish)
      post("/withdraw", OfferController, :withdraw)
    end

    resources("/inventory", InventoryController, only: [:create, :delete, :show], singleton: true) do
      get("/my_ebay_selling", InventoryController, :my_ebay_selling)
      post("/update_sku", InventoryController, :update_sku)
      get("/sku_validation", InventoryController, :sku_validation)
      get("/grid_collection", InventoryController, :grid_collection)
      put("/update_price_and_quantity", InventoryController, :update_price_and_quantity)
      post("/migration", InventoryController, :migration)
      post("/bulk_update_qty_price", InventoryController, :bulk_update_qty_price)
      post("/product_compatibility", InventoryController, :create_product_compatibility)
      delete("/product_compatibility", InventoryController, :delete_product_compatibility)
      get("/product_compatibility", InventoryController, :get_product_compatibility)
      post("/bulk_update", InventoryController, :bulk_update)

      put(
        "/update_big_commerce_inventory/:product_id/:sku",
        InventoryController,
        :update_big_commerce_inventory
      )
    end

    resources("/orders", OrderController, only: [:show, :update], singleton: true)

    resources("/messages", EbayMessageController, only: [:index, :update])
    post("/messages/reply", EbayMessageController, :reply)

    resources("/integrations/bc", BigCommerceIntegrationController,
      only: [:create, :delete, :show],
      singleton: true
    )

    resources("/all_mvl_data", MVLController, only: [:create, :delete, :show], singleton: true) do
      put("/", MVLController, :create)
    end

    post("/publish_parent_product", MVLController, :publish)
    post("/withdraw_by_inventory_item_group", MVLController, :withdraw)
    post("/set_notification_preferences", NotificationController, :subscribe)
  end

  scope "/api/auth/admin", SellSetGoApiWeb do
    pipe_through([:api, :authenticated, :JSON])

    resources("/categories", AdminController, only: [:create])
  end

  scope "/", SellSetGoApiWeb do
    pipe_through([:api])
    match(:*, "/*any", SessionController, :invalid_route)
  end
end
