defmodule SellSetGoApiWeb.OfferController do
  use SellSetGoApiWeb, :controller
  alias SellSetGoApi.Inventory.Products
  alias SellSetGoApi.Offers.Offers
  alias SellSetGoApi.{Configurations, OauthEbay, Utils}

  action_fallback(SellSetGoApiWeb.FallbackController)

  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "draft"} = params
      ) do
    case Map.put(params, "user_id", current_session_record.user_id)
         |> Offers.create_offer(current_session_record) do
      {:ok, _out} ->
        conn
        |> render("message.json", message: "Draft saved")

      error ->
        error
    end
  end

  def create(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"type" => "submit", "sku" => sku, "offer" => %{"marketplaceId" => marketplace_id}} =
          params
      ) do
    with {:ok, offer} <-
           Map.put(params, "user_id", current_session_record.user_id)
           |> Offers.create_offer(current_session_record),
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("offer", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.put_header("content-type", "application/json")
           |> OAuth2.Client.put_header(
             "content-language",
             Utils.get_content_language(marketplace_id)
           ),
         {:ok, %OAuth2.Response{body: %{"offerId" => offer_id} = offer_resp}} <-
           OAuth2.Client.post(
             client,
             Utils.get_route("offer", "EBAY"),
             Map.put(offer.offer_detail, "sku", sku)
             |> Map.put(
               "listingDescription",
               Configurations.compute_description_template(
                 current_session_record.user_id,
                 offer.offer_detail |> Map.put("listing_id", offer.listing_id),
                 sku
               )
             )
           ),
         {:ok, _offer} <-
           Offers.update_offer(offer, %{
             "is_submitted" => true,
             "offer_id" => offer_id
           }),
         {:ok, _product} <-
           Products.update_product_by_sku(sku, %{"is_submitted" => true}, current_session_record),
         {:ok, %OAuth2.Response{body: response}} <-
           OAuth2.Client.post(
             client,
             Utils.get_route("offer", "EBAY") <> "/get_listing_fees",
             %{"offers" => [offer_resp]}
           ) do
      conn
      |> render("offer.json", offer: response |> Map.put("offerId", offer_id))
    else
      {:error, %OAuth2.Error{}} ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", message: "Invalid domain/credentials")

      error ->
        error
    end
  end

  def update(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"offerId" => offer_id, "marketplaceId" => marketplace_id} = params
      ) do
    with {:ok, offer} <-
           Offers.update_by_offer_id(offer_id, params),
         {:ok, %OAuth2.Response{body: _body}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("offer", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.put_header("content-type", "application/json")
           |> OAuth2.Client.put_header(
             "content-language",
             Utils.get_content_language(marketplace_id)
           )
           |> OAuth2.Client.put(
             Utils.get_route("offer", "EBAY") <> "/#{offer_id}",
             offer.offer_detail
             |> Map.put(
               "listingDescription",
               Configurations.compute_description_template(
                 current_session_record.user_id,
                 offer.offer_detail |> Map.put("listing_id", offer.listing_id),
                 offer.sku
               )
             )
           ) do
      conn
      |> render("offer.json", offer: offer)
    end
  end

  def publish(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"offerId" => offer_id, "marketplaceId" => marketplace_id}
      ) do
    with {:ok, %OAuth2.Response{body: %{"listingId" => listing_id} = response}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("offer", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.put_header("content-type", "application/json")
           |> OAuth2.Client.put_header(
             "content-language",
             Utils.get_content_language(marketplace_id)
           )
           |> OAuth2.Client.post(Utils.get_route("offer", "EBAY") <> "/#{offer_id}/publish/"),
         {:ok, offer} <-
           Offers.update_by_offer_id(
             offer_id,
             %{"listing_id" => listing_id, "status" => "active"}
           ),
         {:ok, _product} <-
           Products.update_product_by_sku(
             offer.sku,
             %{"status" => "active"},
             current_session_record
           ) do
      conn
      |> render("offer.json", offer: response)
    end
  end

  def withdraw(
        %{assigns: %{current_session_record: current_session_record}} = conn,
        %{"offerId" => offer_id, "marketplaceId" => marketplace_id}
      ) do
    with {:ok, %OAuth2.Response{body: response}} <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("offer", "EBAY"),
             current_session_record
           )
           |> OAuth2.Client.put_header("content-type", "application/json")
           |> OAuth2.Client.put_header(
             "content-language",
             Utils.get_content_language(marketplace_id)
           )
           |> OAuth2.Client.post(Utils.get_route("offer", "EBAY") <> "/#{offer_id}/withdraw"),
         {:ok, offer} <-
           Offers.update_by_offer_id(
             offer_id,
             %{"status" => "ended"}
           ),
         {:ok, _product} <-
           Products.update_product_by_sku(
             offer.sku,
             %{"status" => "ended"},
             current_session_record
           ) do
      conn
      |> render("offer.json", offer: response)
    end
  end

  def show(%{assigns: %{current_session_record: csr}} = conn, %{
        "sku" => sku,
        "resource_name" => "availableQuantity",
        "marketplace_id" => _marketplace_id
      }) do
    case Products.get_product_by_sku(sku, csr) do
      nil ->
        {:error, "Inventory item not found"}

      product ->
        offer_details =
          Enum.map(product.variant_skus || [product.sku], fn sku ->
            with client <-
                   OauthEbay.session_to_client(
                     "Bearer",
                     Utils.get_host("inventory_item"),
                     csr
                   ),
                 {:ok, %OAuth2.Response{body: response}} <-
                   OAuth2.Client.get(
                     client,
                     Utils.get_route("offer") <>
                       "?sku=#{sku |> URI.encode(&URI.char_unreserved?/1)}"
                   ) do
              response["offers"]
              |> Enum.map(
                &%{
                  "marketplace_id" => &1["marketplaceId"],
                  "availableQuantity" => &1["availableQuantity"],
                  "sku" => &1["sku"],
                  "offer_id" => &1["offerId"],
                  "status" => &1["status"],
                  "listingPolicies" => %{
                    "fulfillmentPolicyId" => &1["listingPolicies"]["fulfillmentPolicyId"],
                    "paymentPolicyId" => &1["listingPolicies"]["paymentPolicyId"],
                    "returnPolicyId" => &1["listingPolicies"]["returnPolicyId"]
                  },
                  "listing_id" => &1["listing"]["listingId"]
                }
              )
            else
              {:error, %OAuth2.Response{body: response}} -> response
            end
          end)
          |> List.flatten()

        conn
        |> put_status(200)
        |> render("offer.json", offer: offer_details)
    end
  end

  def show(%{assigns: %{current_session_record: csr}} = conn, %{"sku" => sku}) do
    case Offers.get_offer_by_sku(sku, csr) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render("message.json", message: "Inventory item not found")

      offer ->
        conn
        |> render("offer.json", offer: offer)
    end
  end
end
