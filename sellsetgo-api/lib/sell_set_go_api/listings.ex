defmodule SellSetGoApi.Listings do
  @moduledoc """
  The Listings context.
  """

  import Ecto.Query, warn: false
  alias EbayXmlApi.{Trading, UploadSiteHostedPictures}
  alias SellSetGoApi.{Admin, EbayXml, OauthEbay, Repo, Reports, Utils, Configurations}

  alias SellSetGoApi.Inventory.{
    BulkQtyPriceRevision,
    Product,
    Products,
    VariationProduct,
    VariationProducts
  }

  alias SellSetGoApi.Listings.Image
  alias SellSetGoApi.Offers.{Offer, Offers, VariationOffers}
  alias Ecto.Multi

  @doc """
  Returns the list of images.

  ## Examples

      iex> list_images()
      [%Image{}, ...]

  """
  def list_images do
    Repo.all(Image)
  end

  @doc """
  Gets a single image.

  Raises `Ecto.NoResultsError` if the Image does not exist.

  ## Examples

      iex> get_image!(123)
      %Image{}

      iex> get_image!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image!(id), do: Repo.get!(Image, id)

  def get_image_by(%{s3_url: s3_url, user_id: user_id}) do
    from(i in Image,
      where: i.s3_url == ^s3_url and i.user_id == ^user_id,
      limit: 1,
      order_by: [desc: i.inserted_at]
    )
    |> Repo.one()
  end

  @doc """
  Creates a image.

  ## Examples

      iex> create_image(%{field: value})
      {:ok, %Image{}}

      iex> create_image(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image(user_id, attrs \\ %{}) do
    generate_put_urls(attrs, user_id)
  end

  @doc """
  Updates a image.

  ## Examples

      iex> update_image(image, %{field: new_value})
      {:ok, %Image{}}

      iex> update_image(image, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a image.

  ## Examples

      iex> delete_image(image)
      {:ok, %Image{}}

      iex> delete_image(image)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image(%Image{} = image) do
    Repo.delete(image)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image changes.

  ## Examples

      iex> change_image(image)
      %Ecto.Changeset{data: %Image{}}

  """
  def change_image(%Image{} = image, attrs \\ %{}) do
    Image.changeset(image, attrs)
  end

  def get_bc_image_urls(sku) do
    query = from i in Image, where: i.sku == ^sku
    Repo.all(query)
  end

  @doc """
  The images is expected to be a list of file details map for generating
  pre-signed urls.
  [%{file_size: size, file_name: name, file_type: type}]
  """
  def generate_put_urls(images, user_id) do
    expiry = String.to_integer(System.get_env("S3_PUT_URL_EXPIRY", "300"))
    bucket = System.get_env("LISTING_IMAGES_BUCKET", "dev-ebay-sellers-listing-images")

    {db_record, _reply_url, reply_image_map} =
      images
      |> Enum.with_index()
      |> Enum.reduce({[], [], []}, fn {image, index}, {acc1, acc2, acc3} ->
        file_type = Map.fetch!(image, "file_type")

        file_name =
          Utils.generate_rand_str() <>
            Map.get(
              image,
              "file_name",
              "#{Utils.generate_rand_str()}-#{index}#{Utils.get_image_ext(file_type)}"
            )

        file_size = Map.fetch!(image, "file_size")

        image_map = %{
          s3_bucket: bucket,
          s3_path: user_id,
          file_name: file_name,
          file_type: file_type,
          file_size: file_size,
          expires_in: expiry,
          type: :put
        }

        {:ok, output_url} =
          Utils.generate_s3_url(image_map, System.get_env("S3_HOST_DOMAIN_URL", "localhost"))

        url =
          output_url
          |> URI.parse()
          |> Map.put(:query, nil)
          |> URI.to_string()

        db_image_map = %{
          s3_url: url,
          order: index,
          user_id: user_id,
          provider: "EBAY",
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        reply_image_map = %{
          file_name: file_name,
          file_type: file_type,
          file_size: file_size,
          s3_url: output_url
        }

        {[db_image_map | acc1], [output_url | acc2], [reply_image_map | acc3]}
      end)

    case db_record_insert(db_record) do
      {:ok, db_record_inserted} ->
        return_image_data(db_record_inserted, reply_image_map)

      {:error, _op_code, changeset, _result} ->
        {:error, changeset}
    end
  end

  def db_record_insert(db_record) do
    db_record
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {image_map, index}, acc_multi ->
      acc_string = "insert#{index}"
      image_changeset = Image.changeset(%Image{}, image_map)
      acc_multi |> Ecto.Multi.insert(String.to_atom(acc_string), image_changeset)
    end)
    |> Repo.transaction()
  end

  def return_image_data(db_record_inserted, reply_image_map) do
    image_data =
      db_record_inserted
      |> Enum.map(fn {_key, db_record} ->
        Enum.find(reply_image_map, fn %{s3_url: s3_url} ->
          String.contains?(s3_url, db_record.s3_url <> "?")
        end)
        |> Map.put(:id, db_record.id)
      end)

    {:ok, image_data}
  end

  def update_provider_image_url(ids, %{user_access_token: uat, user_id: user_id}, sku) do
    urls = get_not_uploaded_s3_urls_from_ids(ids, user_id)

    message =
      Enum.reduce(urls, [], fn s3_url, errors ->
        try do
          with image <- get_image_by(%{s3_url: s3_url, user_id: user_id}),
               processed_req_data <-
                 UploadSiteHostedPictures.get_upload_pictures(
                   url: s3_url,
                   pic_name: ""
                 ),
               {:ok, processed_req_hdrs} <-
                 Utils.prep_headers(uat, processed_req_data),
               {:ok, resp} <-
                 EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
               {:ok, resp_struct} <-
                 UploadSiteHostedPictures.get_upload_pictures_response(resp.body),
               {:ok, _image} <-
                 update_image(image, %{
                   "provider_image_url" => Map.get(resp_struct, :FullURL),
                   "sku" => sku
                 }) do
            errors
          end
        rescue
          FunctionClauseError ->
            errors ++ ["URL: #{s3_url} not found in current user"]

          Protocol.UndefinedError ->
            errors ++ ["URL: #{s3_url} have issue with uploading to the provider"]
        end
      end)

    if message == [] do
      {:ok, %{}}
    else
      {:error, message}
    end
  end

  def get_not_uploaded_s3_urls_from_ids(ids, user_id) do
    from(i in Image,
      where:
        i.id in ^ids and i.user_id == ^user_id and is_nil(i.provider_image_url) and
          not is_nil(i.s3_url),
      select: i.s3_url,
      order_by: i.order
    )
    |> Repo.all()
  end

  def create_image_from_url(url, user_id, provider, sku) do
    %Image{}
    |> Image.changeset(%{s3_url: url, user_id: user_id, provider: provider, sku: sku})
    |> Repo.insert!()
  end

  def get_provider_image_urls_from_ids(ids, user_id) do
    from(i in Image,
      where: i.id in ^ids and i.user_id == ^user_id and not is_nil(i.provider_image_url),
      select: i.provider_image_url,
      order_by: i.order
    )
    |> Repo.all()
  end

  def get_images_from_ids(ids, user_id) do
    from(i in Image,
      where: i.id in ^ids and i.user_id == ^user_id,
      select: %{
        s3_url: i.s3_url,
        provider_image_url: i.provider_image_url,
        sku: i.sku,
        id: i.id,
        order: i.order,
        user_id: i.user_id,
        provider: i.provider,
        inserted_at: i.inserted_at,
        updated_at: i.updated_at
      },
      order_by: [i.order]
    )
    |> Repo.all()
  end

  def get_image_ids_by_sku(sku, user_id) do
    from(i in Image,
      where: i.sku == ^sku and i.user_id == ^user_id,
      select: i.id
    )
    |> Repo.all()
  end

  def get_image_by_id(id, user_id) do
    Image
    |> where([i], i.id == ^id and i.user_id == ^user_id)
    |> select([i], i.provider_image_url)
    |> Repo.one()
  end

  def my_ebay_selling(%{user_access_token: uat, user_id: user_id}, %{
        "entries_per_page" => entries_per_page,
        "page_number" => page_number,
        "marketplace_id" => marketplace_id
      }) do
    with true <- String.to_integer(entries_per_page) <= 200,
         processed_req_data <-
           Trading.my_ebay_selling(entries: entries_per_page, page_number: page_number),
         {:ok, processed_req_hdrs} <-
           Utils.prep_headers(uat, processed_req_data, Utils.get_site_id(marketplace_id)),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs),
         {:ok, %{ItemArray: %{Item: item}, PaginationResult: pagination_result}} <-
           Trading.get_my_ebay_sell_response(resp.body),
         response <- ssg_db_check(item, user_id, entries_per_page) do
      %{entries: response}
      |> Map.merge(pagination_result)
      |> then(fn result -> {:ok, result} end)
    else
      {:ok, msg} ->
        {:ok, msg}

      false ->
        {:error, "Entries_per_page is more. Entries per page should be less than or equal to 200"}
    end
  end

  def update_sku(%{user_access_token: uat, user_id: user_id}, %{
        "item_id" => item_id,
        "sku" => sku
      }) do
    with false <- sku_validation(user_id, sku),
         processed_req_data <-
           Trading.update_sku(item_id: item_id, sku: sku),
         {:ok, processed_req_hdrs} <-
           Utils.prep_headers(uat, processed_req_data),
         {:ok, resp} <-
           EbayXml.post("/ws/api.dll", processed_req_data.body, processed_req_hdrs) do
      Trading.get_update_sku_resp(resp.body)
    else
      true ->
        {:error, "The given sku is already present in DB. Please change sku and try again"}
    end
  end

  def sku_validation(user_id, skus) when is_list(skus) do
    existing_skus =
      from(Product)
      |> where([p], p.sku in ^skus and p.user_id == ^user_id)
      |> select([p], p.sku)
      |> Repo.all()

    %{
      existing: existing_skus,
      non_existing: skus -- existing_skus
    }
  end

  def sku_validation(user_id, sku) do
    from(Product)
    |> where([p], p.sku == ^sku and p.user_id == ^user_id)
    |> Repo.exists?()
  end

  def sku_validation(user_id, parent_skus, child_skus) do
    query =
      from(Product)
      |> where([p], p.sku in ^parent_skus and p.user_id == ^user_id)
      |> select([p], p.sku)

    existing_skus =
      from(VariationProduct)
      |> where([vp], vp.sku in ^child_skus and vp.user_id == ^user_id)
      |> select([vp], vp.sku)
      |> union(^query)
      |> Repo.all()

    %{
      existing: existing_skus
    }
  end

  @doc """
  This function checks if a product SKU exists in the system and returns a boolean value indicating whether the SKU exists or not.
  """
  def sku_validation(sku) do
    Product
    |> where(sku: ^sku)
    |> Repo.exists?()
  end

  defp ssg_db_check(ebay_sellings, user_id, entries_per_page) do
    ebay_sellings =
      if entries_per_page == "1" do
        [ebay_sellings]
      else
        ebay_sellings
      end

    item_id_sku =
      ebay_sellings
      |> Enum.reduce([], fn
        %{
          ItemID: item_id
        } = params,
        acc ->
          [
            %{
              item_id: item_id,
              item_title: params[:Title],
              price: params[:BuyItNowPrice],
              format: params[:ListingType],
              quantity: params[:QuantityAvailable],
              is_sku_exist: sku_validation(user_id, "#{params[:SKU]}"),
              is_multi_variation: !is_nil(params[:Variations]),
              sku: params[:SKU] || ""
            }
            | acc
          ]
      end)

    item_ids =
      item_id_sku
      |> Enum.reduce([], fn %{item_id: item_id}, acc ->
        [
          Integer.to_string(item_id)
          | acc
        ]
      end)

    item_ids_in_ssg =
      from(o in Offer,
        where: o.listing_id in ^item_ids and o.user_id == ^user_id,
        select: o.listing_id
      )
      |> Repo.all()

    item_id_sku
    |> Enum.filter(fn %{item_id: item_id} ->
      Integer.to_string(item_id) not in item_ids_in_ssg
    end)
  end

  def grid_collection(
        %{user_id: user_id},
        %{
          "marketplace_id" => marketplace_id,
          "status" => status,
          "page_size" => page_size,
          "page_no" => page_no
        } = params
      ) do
    sort_by = (params["sort_by"] || "inserted_at") |> String.to_atom()
    sort_type = params["sort_type"] || "asc"
    category_id = params["ebaycatid"]

    values = sorting_value(sort_by, sort_type)
    search_term = "%#{params["search_term"]}%"

    query =
      from(o in Offer,
        join: p in Product,
        on: o.sku == p.sku and o.user_id == p.user_id,
        where:
          o.marketplace_id == ^marketplace_id and o.user_id == ^user_id and o.status == ^status,
        where:
          ilike(o.sku, ^search_term) or ilike(o.listing_id, ^search_term) or
            ilike(p.title, ^search_term),
        select: %{
          sku: o.sku,
          listing_id: o.listing_id,
          status: o.status,
          offer_id: o.offer_id,
          title: p.title,
          quantity: p.quantity,
          image_ids: p.image_ids,
          inserted_at: o.inserted_at,
          updated_at: o.updated_at,
          price: o.offer_detail["pricingSummary"]["price"]["value"],
          currency: o.offer_detail["pricingSummary"]["price"]["currency"],
          marketplace_id: o.marketplace_id,
          available_quantity: o.offer_detail["availableQuantity"],
          variant_skus: p.variant_skus
        },
        order_by: ^values
      )
      |> add_category_id_filter(category_id)

    %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
      query
      |> Repo.paginate(%{page_size: page_size, page: page_no})

    image_urls =
      Enum.reduce(entries, [], fn %{image_ids: image_ids}, acc -> image_ids ++ acc end)
      |> get_image_url_by_ids(user_id)
      |> Enum.filter(fn x -> Enum.find(entries, &(&1.sku == x.sku)) end)

    grid_collections = form_grid_collection_params(entries, image_urls, sort_by, sort_type)
    {:ok, grid_collections, total_entries, total_pages}
  end

  defp add_category_id_filter(query, category_id) do
    if category_id,
      do: where(query, [_, _], fragment("offer_detail->'categoryId'") == ^category_id),
      else: query
  end

  defp form_grid_collection_params(entries, image_urls, sort_by, sort_type) do
    (entries ++ image_urls)
    |> Enum.group_by(fn %{sku: sku} -> sku end)
    |> Enum.map(fn {_key, val} ->
      product = Enum.reduce(val, %{}, fn map, acc -> Map.merge(map, acc) end)

      Map.merge(product, %{
        product_type: if(product.variant_skus, do: "parent", else: nil),
        variant_products_count: length(product.variant_skus || [])
      })
      |> Map.drop([:image_ids, :variant_skus])
    end)
    |> Enum.sort_by(
      fn x ->
        value = x[sort_by]

        if is_bitstring(value) do
          String.downcase(value)
        else
          value
        end
      end,
      String.to_atom(sort_type)
    )
  end

  defp sorting_value(:price, sort_type) do
    if sort_type == "asc" do
      dynamic([o, p], fragment("? ASC", o.offer_detail["pricingSummary"]["price"]["value"]))
    else
      dynamic([o, p], fragment("? DESC", o.offer_detail["pricingSummary"]["price"]["value"]))
    end
  end

  defp sorting_value(sort_by, sort_type)
       when sort_by in [:listing_id, :offer_id, :sku, :inserted_at, :updated_at] do
    if sort_type == "asc" do
      dynamic([o, p], fragment("? ASC", field(o, ^sort_by)))
    else
      dynamic([o, p], fragment("? DESC", field(o, ^sort_by)))
    end
  end

  defp sorting_value(sort_by, sort_type) when sort_by in [:title, :quantity] do
    if sort_type == "asc" do
      dynamic([o, p], fragment("? ASC", field(p, ^sort_by)))
    else
      dynamic([o, p], fragment("? DESC", field(p, ^sort_by)))
    end
  end

  defp sorting_value(_sort_by, _sort_type) do
    dynamic([o, p], fragment("? ASC", field(o, :inserted_at)))
  end

  def get_image_url_by_ids(all_image_ids, user_id) do
    from(i in Image,
      where: i.id in ^all_image_ids and i.user_id == ^user_id,
      select: %{provider_url: i.provider_image_url, sku: i.sku, s3_url: i.s3_url}
    )
    |> Repo.all()
    |> Enum.map(fn image ->
      image_url = image.provider_url || image.s3_url

      %{
        sku: image.sku,
        image_url: image_url
      }
    end)
  end

  def migration(
        current_session_record,
        marketplace_id,
        listing_ids,
        migration
      ) do
    processed_listing_ids =
      listing_ids
      |> Enum.reduce([], fn %{"listing_id" => listing_id}, acc ->
        [
          %{listingId: listing_id}
          | acc
        ]
      end)

    with content_language <- Utils.get_content_language(marketplace_id),
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory_item"),
             current_session_record
           ),
         client <-
           OAuth2.Client.put_header(client, "content-type", "application/json"),
         client <- OAuth2.Client.put_header(client, "content-language", content_language),
         route <- Utils.get_route(migration),
         {:ok, %OAuth2.Response{body: body}} <-
           OAuth2.Client.post(client, route, %{requests: processed_listing_ids}, [],
             recv_timeout: 30_000
           ) do
      {:ok, body}
    else
      {:error, response} ->
        {:error, response}
    end
  end

  defp migrate_product_to_db(result, csr) do
    try do
      sku = fetch_sku(result)

      with client <-
             OauthEbay.session_to_client(
               "Bearer",
               Utils.get_host("inventory_item"),
               csr
             ),
           {:ok, %OAuth2.Response{body: response}} <-
             OAuth2.Client.get(
               client,
               Utils.get_route("inventory_item") <>
                 "/#{sku |> URI.encode(&URI.char_unreserved?/1)}"
             ) do
        format_and_insert_into_product(response, csr.user_id)
      else
        _ -> {:error, "Error while fetching eBay item"}
      end
    rescue
      _ -> {:error, "Error while fetching SKU"}
    end
  end

  defp migrate_offer_to_db(result, csr) do
    try do
      sku = fetch_sku(result)

      with client <-
             OauthEbay.session_to_client(
               "Bearer",
               Utils.get_host("inventory_item"),
               csr
             ),
           {:ok, %OAuth2.Response{body: response}} <-
             OAuth2.Client.get(
               client,
               Utils.get_route("offer") <> "?sku=#{sku |> URI.encode(&URI.char_unreserved?/1)}"
             ) do
        format_and_insert_into_offer(response["offers"], csr.user_id)
      else
        _ -> {:error, "Error while fetching eBay offer"}
      end
    rescue
      _ -> {:error, "Error while fetching SKU"}
    end
  end

  def migrate_product_and_offer(result, csr) do
    Multi.new()
    |> Multi.run(:create_product, fn _repo, _cond ->
      migrate_product_to_db(result, csr)
    end)
    |> Multi.run(:create_offer, fn _repo, _cond ->
      migrate_offer_to_db(result, csr)
    end)
    |> Repo.transaction()
  end

  def get_all_categories_for_user(user_id, marketplace_id) do
    from(o in Offer,
      where:
        o.user_id == ^user_id and o.marketplace_id == ^marketplace_id and o.status == "active" and
          not is_nil(o.offer_detail["categoryId"])
    )
    |> Repo.all()
    |> Enum.group_by(fn %{offer_detail: %{"categoryId" => category_id}} -> category_id end)
    |> Enum.reduce([], fn {cat_id, list}, acc ->
      if cat_id != nil do
        offer_detail = Map.get(List.first(list), :offer_detail)

        [
          %{
            category_id: cat_id,
            category_full_path:
              get_ebay_category_full_path(
                cat_id,
                offer_detail["ebayCategoryNames"],
                marketplace_id
              ),
            no_of_active_listing: length(list)
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp get_ebay_category_full_path(category_id, cat_names, marketplace_id)
       when cat_names in [[], nil, ""] do
    category_id = if is_binary(category_id), do: String.to_integer(category_id), else: category_id
    get_ebay_category_names(category_id, marketplace_id)
  end

  defp get_ebay_category_full_path(_category_id, cat_names, _marketplace_id) do
    cat_names |> List.first()
  end

  defp format_and_insert_into_product(%{"sku" => sku} = product, user_id) do
    images =
      get_in(product, ["product", "imageUrls"])
      |> Enum.with_index()
      |> Enum.map(fn {image, index} ->
        %{
          order: index,
          sku: sku,
          provider: "EBAY",
          provider_image_url: image,
          user_id: user_id,
          s3_url: image,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)

    Repo.insert_all(Image, images)

    image_ids = get_image_ids_by_sku(sku, user_id)

    product_params = %{
      aspects: %{dynamic: get_in(product, ["product", "aspects"])},
      condition: product["condition"],
      description: product["description"],
      image_ids: image_ids,
      is_submitted: true,
      package_weight_and_size: product["packageWeightAndSize"],
      quantity: get_in(product, ["availability", "shipToLocationAvailability", "quantity"]),
      sku: sku,
      status: "active",
      title: get_in(product, ["product", "title"]),
      user_id: user_id,
      ean: product["product"] && product["product"]["ean"]
    }

    %Product{}
    |> Product.changeset(product_params)
    |> Repo.insert()
  end

  defp format_and_insert_into_offer(offers, user_id) do
    formatted_offers =
      Enum.map(offers, fn %{"sku" => sku, "marketplaceId" => marketplace_id} = offer ->
        offer_detail = %{
          format: offer["format"],
          categoryId: offer["categoryId"],
          marketplaceId: marketplace_id,
          pricingSummary: offer["pricingSummary"],
          listingDuration: offer["listingDuration"],
          listingPolicies: offer["listingPolicies"],
          availableQuantity: get_ebay_quantity(offer["availableQuantity"], sku, user_id),
          listingDescription: offer["listingDescription"],
          storeCategoryNames: offer["storeCategoryNames"],
          merchantLocationKey: offer["merchantLocationKey"],
          ebayCategoryNames: [
            get_ebay_category_names(String.to_integer(offer["categoryId"]), marketplace_id)
          ],
          tax: offer["tax"]
        }

        %{
          is_submitted: true,
          listing_id: get_in(offer, ["listing", "listingId"]),
          offer_detail: offer_detail,
          offer_id: offer["offerId"],
          sku: sku,
          status: "active",
          user_id: user_id,
          marketplace_id: marketplace_id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)

    {count, _} = Repo.insert_all(Offer, formatted_offers)
    offers_length = length(offers)

    if count == offers_length do
      {:ok, count}
    else
      {:error,
       "failed to insert all offers - #{count} success and #{offers_length - count} failed"}
    end
  end

  defp fetch_sku(%{"responses" => responses}) do
    responses
    |> List.first()
    |> get_in(["inventoryItems"])
    |> List.first()
    |> get_in(["sku"])
  end

  defp get_ebay_quantity(nil, sku, user_id) do
    Repo.get_by(Product, sku: sku, user_id: user_id)
    |> Map.get(:quantity)
  end

  defp get_ebay_quantity(quantity, _sku, _user_id), do: quantity

  def get_ebay_category_names(category_id, marketplace_id) do
    cat = Admin.show_admin_categories(marketplace_id).categories["children"]
    get_parent_path_by_id(cat, cat, category_id, "")
  end

  defp get_parent_path_by_id(_cat, [], _id, res), do: res

  defp get_parent_path_by_id(categories, query_cat, id, res) do
    Enum.reduce(query_cat, res, fn category, acc ->
      if category["id"] == id do
        acc = concat_category_names(acc, category)
        get_parent_path_by_id(categories, categories, category["parent"], acc)
      else
        if category["children"] do
          get_parent_path_by_id(categories, category["children"], id, acc)
        end
      end
    end)
  end

  defp concat_category_names("", category) do
    "#{category["name"]} (#{category["id"]})"
  end

  defp concat_category_names(acc, category) do
    category["name"] <> " > " <> acc
  end

  def process_csv(%{user_id: user_id}, csv) do
    %{items_in_db: items_in_db, items_not_in_db: items_not_in_db} =
      read_csv(csv)
      |> split_items_in_db(user_id)

    items_in_db
    |> Enum.map(fn value ->
      value = AtomicMap.convert(value)

      value1 = %{
        user_id: user_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        status: "pending"
      }

      Map.merge(value, value1)
    end)
    |> Enum.uniq_by(fn value -> value[:offer_id] end)
    |> then(fn values ->
      Repo.insert_all(BulkQtyPriceRevision, values,
        conflict_target: [:sku, :offer_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )
    end)

    {items_in_db, items_not_in_db}
  end

  def split_items_in_db(values, user_id) do
    products = Product |> where([p], p.user_id == ^user_id) |> Repo.all()
    skus = Enum.map(products, fn item -> Map.get(item, :sku) end)

    {items_in_db, items_not_in_db} =
      values
      |> Enum.reduce({[], []}, fn
        %{"item_id" => item_id, "sku" => ""} = value, {items_in_db, items_not_in_db} ->
          sku_offer_table =
            from(o in Offer,
              where: o.user_id == ^user_id and o.listing_id == ^item_id and o.status == "active",
              select: %{sku: o.sku, offer_id: o.offer_id}
            )
            |> Repo.one()

          if Utils.is_empty?(sku_offer_table) do
            {items_in_db,
             items_not_in_db ++ [value |> Map.put("error", "This item not present in SSG DB")]}
          else
            {items_in_db ++
               [
                 value
                 |> Map.put("sku", sku_offer_table.sku)
                 |> Map.put("offer_id", sku_offer_table.offer_id)
               ], items_not_in_db}
          end

        %{"sku" => sku} = value, {items_in_db, items_not_in_db} ->
          if sku in skus do
            offer_id =
              from(o in Offer,
                where: o.user_id == ^user_id and o.sku == ^sku and o.status == "active",
                select: o.offer_id
              )
              |> Repo.one()

            remove_nil_offer_id(offer_id, items_in_db, value, items_not_in_db)
          else
            {items_in_db,
             items_not_in_db ++ [Map.put(value, "error", "This item not present in SSG DB")]}
          end
      end)

    %{items_in_db: items_in_db, items_not_in_db: items_not_in_db, products: products, skus: skus}
  end

  defp remove_nil_offer_id(nil, items_in_db, value, items_not_in_db) do
    {items_in_db, items_not_in_db ++ [Map.put(value, "error", "This item not active")]}
  end

  defp remove_nil_offer_id(offer_id, items_in_db, value, items_not_in_db) do
    {items_in_db ++ [Map.put(value, "offer_id", offer_id)], items_not_in_db}
  end

  def revising_price(%{user_id: user_id} = current_session_record, marketplace_id) do
    pending_list =
      from(b in BulkQtyPriceRevision,
        where: b.user_id == ^user_id and b.status == "pending"
      )
      |> Repo.all()

    chunk_lists = Enum.chunk_every(pending_list, 25)

    Enum.map(chunk_lists, fn chunk_list ->
      ebay_hit_lists =
        Enum.reduce(chunk_list, [], fn
          %{
            item_id: _item_id,
            price: price,
            warehouse_qty: warehouse_qty,
            ebay_qty: ebay_qty,
            sku: sku,
            user_id: _user_id,
            offer_id: offer_id
          },
          acc ->
            [
              %{
                offers: [
                  %{
                    availableQuantity: String.to_integer(ebay_qty),
                    offerId: offer_id,
                    price: %{
                      currency: Utils.get_currency(marketplace_id),
                      value: price
                    }
                  }
                ],
                shipToLocationAvailability: %{
                  quantity: warehouse_qty
                },
                sku: sku
              }
              | acc
            ]
        end)

      with content_language <- Utils.get_content_language(marketplace_id),
           client <-
             OauthEbay.session_to_client(
               "Bearer",
               Utils.get_host("inventory_item"),
               current_session_record
             ),
           client <-
             OAuth2.Client.put_header(client, "content-type", "application/json"),
           client <- OAuth2.Client.put_header(client, "content-language", content_language),
           route <- Utils.get_route("bulk_update_price_quantity"),
           {_, %OAuth2.Response{body: %{"responses" => ebay_responses}}} <-
             OAuth2.Client.post(client, route, %{requests: ebay_hit_lists}) do
        Enum.map(ebay_responses, fn
          %{"offerId" => _offer_id} = ebay_response ->
            spilt_updated_and_not_updated(ebay_response, chunk_list, user_id)

          _ ->
            []
        end)
        |> List.flatten()
        |> update_revision_status_in_db(user_id)
      end
    end)
  end

  def read_csv(csv) do
    csv.path
    |> Path.expand()
    |> File.stream!()
    |> CSV.decode(headers: true)
    |> Enum.to_list()
  end

  defp spilt_updated_and_not_updated(ebay_response, chunk_list, user_id) do
    Enum.reduce(chunk_list, %{updated: nil, not_updated: nil}, fn %{offer_id: offer_id} =
                                                                    updated_value,
                                                                  acc ->
      if offer_id == ebay_response["offerId"] and ebay_response["statusCode"] == 200 do
        update_revised_quantity_and_price_in_db(updated_value, user_id)
        %{updated: offer_id}
      else
        if offer_id == ebay_response["offerId"] do
          %{not_updated: offer_id}
        else
          acc
        end
      end
    end)
  end

  defp update_revised_quantity_and_price_in_db(%{sku: sku} = record, user_id) do
    offer =
      from(o in Offer,
        where: o.sku == ^sku and o.user_id == ^user_id and o.status == "active"
      )
      |> Repo.one()

    Products.parse_and_update_offer(
      offer,
      %{"value" => record.price, "currency" => Utils.get_currency(offer.marketplace_id)},
      record.ebay_qty
    )

    Products.update_product_by_sku(sku, %{"quantity" => record.warehouse_qty}, %{user_id: user_id})
  end

  defp update_revision_status_in_db(status_map, user_id) do
    map =
      Enum.reduce(status_map, %{updated: [], not_updated: []}, fn
        %{updated: offer_id}, acc ->
          if Utils.is_empty?(acc[:updated]) do
            %{updated: [offer_id], not_updated: acc[:not_updated]}
          else
            %{updated: [offer_id | acc[:updated]], not_updated: acc[:not_updated]}
          end

        %{not_updated: offer_id}, acc ->
          if Utils.is_empty?(acc[:not_updated]) do
            %{updated: acc[:updated], not_updated: [offer_id]}
          else
            %{updated: acc[:updated], not_updated: [offer_id | acc[:not_updated]]}
          end
      end)

    update_status_in_revision(user_id, map)

    processed_items = map.updated ++ map.not_updated

    from(b in BulkQtyPriceRevision,
      where: b.user_id == ^user_id and b.offer_id in ^processed_items
    )
    |> Repo.all()
  end

  def create_csv_error_file(data, %{user_id: user_id}) do
    file_name = "bulk_price_qty_response_#{DateTime.utc_now() |> DateTime.to_unix()}.csv"

    data_list =
      Enum.map(data, fn val ->
        [
          get_from_map(val, "sku"),
          get_from_map(val, "item_id"),
          get_from_map(val, "price"),
          get_from_map(val, "warehouse_qty"),
          get_from_map(val, "ebay_qty"),
          get_from_map(val, "error")
        ]
      end)

    ([["sku", "item_id", "price", "warehouse_qty", "ebay_qty", "status"]] ++ data_list)
    |> CSV.encode(delimiter: "\n")
    |> Stream.into(File.stream!(file_name, [:write, :utf8]))
    |> Stream.run()

    Reports.upload_to_s3(file_name, "bulk_price_qty_response", user_id)
  end

  def add_resp_status(csv, processed_data, status) do
    csv_data =
      Path.expand(csv.path)
      |> File.stream!()
      |> CSV.decode()
      |> Enum.map(fn data -> data end)

    for index <- 0..(length(csv_data) - 1) do
      csv_data = Enum.at(csv_data, index)

      if(index == 0) do
        csv_data ++ ["error", "status"]
      else
        processed_data = Enum.at(processed_data, index - 1)
        csv_data ++ [processed_data["error"], status]
      end
    end
  end

  defp update_status_in_revision(user_id, %{updated: nil, not_updated: not_updated_ids}) do
    from(b in BulkQtyPriceRevision,
      where: b.user_id == ^user_id and b.offer_id in ^not_updated_ids
    )
    |> Repo.update_all(set: [status: "not_updated"])
  end

  defp update_status_in_revision(user_id, %{updated: updated_ids, not_updated: nil}) do
    from(b in BulkQtyPriceRevision,
      where: b.user_id == ^user_id and b.offer_id in ^updated_ids
    )
    |> Repo.update_all(set: [status: "updated"])
  end

  defp update_status_in_revision(user_id, %{updated: updated_ids, not_updated: not_updated_ids}) do
    from(b in BulkQtyPriceRevision,
      where: b.user_id == ^user_id and b.offer_id in ^updated_ids
    )
    |> Repo.update_all(set: [status: "updated"])

    from(b in BulkQtyPriceRevision,
      where: b.user_id == ^user_id and b.offer_id in ^not_updated_ids
    )
    |> Repo.update_all(set: [status: "not_updated"])
  end

  defp get_from_map(map, "error") do
    Map.get(map, "error") || get_error_status(map)
  end

  defp get_from_map(map, key) do
    Map.get(map, "#{key}") || Map.get(map, :"#{key}")
  end

  defp get_error_status(%{status: "updated"}), do: nil
  defp get_error_status(%{status: "not_updated"}), do: "Problem Updating in EBay"

  @doc """
      Decoding csv file content into elixir maps and
      to check whether the File has exceeded the limit of 2000 records
  """
  def read_csv_for_bulk_create(csv) do
    result =
      Path.expand(csv.path)
      |> File.stream!()
      |> CSV.decode(headers: true)
      |> Enum.map(fn data -> data end)

    if length(result) < 2002,
      do: {:ok, result},
      else: {:error, "File has exceeded the limit of 2000 records"}
  end

  @doc """
      Checking whether all the mandatory fields are  present in the csv data or not.
  """
  def csv_validation(data, csr) do
    skus = Enum.map(data, & &1["sku"])

    parent_skus =
      Enum.reduce(data, [], fn x, acc ->
        if(x["producttype"] != "Child",
          do: [x["sku"] | acc],
          else: acc
        )
      end)

    used_parent_skus = Products.get_used_skus(parent_skus, csr)
    child_skus = skus -- parent_skus
    used_child_skus = VariationProducts.get_used_skus(child_skus, csr)
    all_site_ids = Utils.get_all_global_ids()
    used_site_ids = Enum.map(data, & &1["siteid"]) |> Enum.uniq()
    used_currencies = Utils.get_currencies(used_site_ids)

    merchant_location_keys = get_merchant_locations(csr)

    fulfillment_ids = get_fulfillment_ids(used_site_ids, csr)
    payment_ids = get_payment_ids(used_site_ids, csr)
    return_ids = get_return_ids(used_site_ids, csr)

    {data, image_params} =
      Enum.reduce(data, {[], []}, fn product, {data, image_params} ->
        product =
          put_in(product, ["success"], "")
          |> put_in(["error"], "")
          |> remove_spaces()
          |> validate_mandatory_fields()
          |> check_sku_duplication(skus)
          |> child_sku_validation(used_child_skus)
          |> parent_sku_validation(used_parent_skus)
          |> validate_site_id(all_site_ids)
          |> add_and_update_values(csr)
          |> stitch_currency(used_currencies)

        image_ids =
          String.split(product["images"], ",")
          |> Enum.map(&{&1, Ecto.UUID.generate()})

        images = form_bulk_image_params(image_ids, product, csr)

        product = put_in(product, ["image_ids"], Enum.map(image_ids, &elem(&1, 1)))

        product =
          if(product["producttype"] != "Parent" && used_site_ids -- all_site_ids == []) do
            product
            |> merchant_location_key_validation(merchant_location_keys)
            |> fulfillment_validation(fulfillment_ids)
            |> payment_validation(payment_ids)
            |> return_validation(return_ids)
          else
            product
          end

        {data ++ [product], image_params ++ images}
      end)

    if Enum.all?(data, &(&1["error"] in ["", nil])),
      do: {:ok, data, image_params},
      else: {:error, data}
  end

  def remove_spaces(product) do
    product
    |> Map.put("variantskus", clean_string(product["variantskus"]))
    |> Map.put("aspectsvariesby", clean_string(product["aspectsvariesby"]))
    |> Map.put("images", remove_line_characters(product["images"]))
  end

  defp clean_string(string) do
    string
    |> remove_line_characters()
    |> String.trim()
  end

  defp remove_line_characters(string), do: Regex.replace(~r/(\n|\t|\r)/, string, "")

  def stitch_currency(product, used_currencies) do
    used_currency = Enum.find(used_currencies, &(&1.site_id == product["siteid"]))
    put_in(product, ["currency"], used_currency.currency)
  end

  def create_bulk_images(image_params) do
    if Image.changeset_valid_for_all?(%Image{}, image_params) do
      Repo.insert_all(Image, image_params,
        conflict_target: [:id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

      {:ok, image_params}
    else
      {:error, "Invalid data"}
    end
  end

  defp form_bulk_image_params(image_ids, product, csr) do
    Enum.map(
      image_ids,
      &%{
        id: elem(&1, 1),
        s3_url: elem(&1, 0),
        user_id: csr.user_id,
        sku: product["sku"],
        type: product["producttype"],
        provider: "EBAY",
        inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
        updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }
    )
  end

  #  Checking whether all the mandatory fields are  present in the csv data or not.
  defp validate_mandatory_fields(product) do
    mandatory = [
      "siteid",
      "producttype",
      "sku",
      "title",
      "categoryid1",
      "price",
      "quantity",
      "images",
      "conditionid",
      "description",
      "merchantlocationkey",
      "packagetype",
      "packageweight",
      "fulfillmentpolicyid",
      "returnpolicyid",
      "paymentpolicyid"
    ]

    empty_columns =
      Map.take(product, get_mandatory_fields(mandatory, product))
      |> Enum.filter(&(elem(&1, 1) == ""))
      |> List.zip()
      |> List.first() || []

    if empty_columns != [] do
      field_names = Tuple.to_list(empty_columns) |> Enum.join(",")
      Map.put(product, "error", "#{field_names} cannot be empty")
    else
      Map.put(product, "error", "")
    end
  end

  # Checking sku uniqueness within the csv data
  defp check_sku_duplication(product, skus) do
    if(Enum.count(skus, &(&1 == product["sku"])) > 1) do
      Map.put(
        product,
        "error",
        update_error_message(product, "SKU should be unique and non-empty")
      )
    else
      product
    end
  end

  # Checking whether the child sku already exists in database
  defp child_sku_validation(product, used_child_skus) do
    if(product["producttype"] == "Child" && product["sku"] in used_child_skus) do
      Map.put(
        product,
        "error",
        update_error_message(product, "SKU already exists in SSG database")
      )
    else
      product
    end
  end

  # Check whether the parent sku already exists in database
  defp parent_sku_validation(product, used_parent_skus) do
    if(product["producttype"] in ["Simple", "Parent"] && product["sku"] in used_parent_skus) do
      Map.put(
        product,
        "error",
        update_error_message(product, "SKU already exists in SSG database")
      )
    else
      product
    end
  end

  #  For api based validation and to update values like image_urls to image_ids e.t.c.
  #      1. Build aspects map
  #      2. Check whether the given condition enum maps with the ssg condition_enum
  #      3. Add listing_duration and format
  #      4. Convert image urls to image ids list
  defp add_and_update_values(product, _csr) do
    Map.put(product, "aspects", build_aspects(product))
    |> Map.put(
      "conditionEnum",
      Map.get(Product.get_condition_enums(), product["conditionid"])
    )
    |> Map.put("format", "FIXED_PRICE")
    |> Map.put("listingDuration", "GTC")

    #    |> Map.put("imageIds", get_image_ids(product, csr))
  end

  # To check whether the given site ids are available in database or not
  defp validate_site_id(product, all_site_ids) do
    if(product["siteid"] in all_site_ids) do
      product
    else
      Map.put(
        product,
        "error",
        update_error_message(product, "Site Id is not present in SSG database")
      )
    end
  end

  @doc """
  Database insertion for products, variation products, offers and variation offers
  """
  def create_bulk_product_and_offer(grouped_data, csr) do
    Multi.new()
    # Inserting simple and parent products into database
    |> Multi.run(:create_products, fn _repo, _cond ->
      create_products_query(grouped_data, csr)
    end)
    # Inserting variation products into database
    |> Multi.run(:create_variation_products, fn _repo, _cond ->
      create_variation_products_query(grouped_data, csr)
    end)
    # Inserting the variation offers into db
    |> Multi.run(:create_variation_offers, fn _repo, _cond ->
      create_variation_offers_query(grouped_data, csr)
    end)
    |> Multi.run(:create_offers, fn _repo, _cond ->
      create_offers_query(grouped_data, csr)
    end)
    |> Repo.transaction()
  end

  defp create_products_query(grouped_data, csr) do
    ((grouped_data["Simple"] || []) ++ (grouped_data["Parent"] || []))
    |> Enum.map(fn product ->
      # Changing product keys according to elixir schema
      parse_product_params(product, csr)
    end)
    |> Products.create_products()
  end

  defp create_variation_products_query(grouped_data, csr) do
    Enum.map(grouped_data["Child"] || [], fn product ->
      # Finding the parent of child product wrt its variation_skus
      parent = get_parent(grouped_data, product)

      # Changing variation product keys according to elixir schema
      parse_vp_params(product, csr, parent)
    end)
    |> VariationProducts.create_products()
  end

  defp create_variation_offers_query(grouped_data, csr) do
    Enum.map(grouped_data["Child"] || [], fn offer ->
      # Finding the parent of child product wrt its variation_skus
      parent = get_parent(grouped_data, offer)

      # Changing variation offer keys according to elixir schema
      form_vo_params(offer, parent["sku"], csr)
    end)
    |> VariationOffers.create_offers()
  end

  defp create_offers_query(grouped_data, csr) do
    ((grouped_data["Simple"] || []) ++ (grouped_data["Parent"] || []))
    |> Enum.map(fn offer ->
      # Finding the parent of child product wrt its variation_skus
      offer =
        if offer["producttype"] == "Parent" do
          variant_skus =
            String.split(
              Regex.replace(~r/(\n|\t|\r)/, offer["variantskus"], ""),
              ","
            )

          # Creating data for parent offers wrt child offers
          child_offer = Enum.find(grouped_data["Child"] || [], &(&1["sku"] in variant_skus))

          Map.merge(
            offer,
            %{
              "merchantlocationkey" => child_offer["merchantlocationkey"],
              "categoryid1" => child_offer["categoryid1"],
              "storecategoryname1" => child_offer["storecategoryname1"],
              "vat" => child_offer["vat"],
              "fulfillmentpolicyid" => child_offer["fulfillmentpolicyid"],
              "returnpolicyid" => child_offer["returnpolicyid"],
              "paymentpolicyid" => child_offer["paymentpolicyid"]
            }
          )
        else
          offer
        end

      # Changing offer keys according to elixir schema
      form_offer_params(offer, csr)
    end)
    |> Offers.create_offers()
  end

  defp get_parent(grouped_data, product) do
    Enum.find(
      grouped_data["Parent"] || [],
      &(product["sku"] in String.split(
          Regex.replace(~r/(\n|\t|\r)/, &1["variantskus"], ""),
          ","
        ))
    )
  end

  @doc """
    Creating the response csv file according status parameter i.e Failed or Success and
    also uploading that file to s3
  """

  def bulk_create_csv_resp(data, csv, %{user_id: user_id}, status) do
    file_name = "bulk_create_response_#{DateTime.utc_now() |> DateTime.to_unix()}.csv"

    add_resp_status(csv, data, status)
    |> CSV.encode(delimiter: "\n")
    |> Stream.into(File.stream!(file_name, [:write, :utf8]))
    |> Stream.run()

    Reports.upload_to_s3(file_name, "bulk_create_response", user_id)
  end

  @doc """
      Changing variation product keys according to elixir schema.
      E.g. converting to camel or snake case
      and adding data like timestamps for insert_all
  """
  def parse_vp_params(%{"sku" => sku} = product, %{user_id: user_id}, parent) do
    %{
      aspects: product["aspects"],
      condition: product["conditionEnum"],
      description: replace_empty_string(product["description"]),
      image_ids:
        if(product["image_ids"] in [nil, []], do: parent["image_ids"], else: product["image_ids"]),
      package_weight_and_size: %{
        "packageType" => product["packagetype"],
        "weight" => %{
          "value" => get_weight_from_string(product["packageweight"]),
          "unit" => "KILOGRAM"
        }
      },
      quantity: String.to_integer(product["quantity"]),
      sku: sku,
      title: replace_empty_string(product["title"]),
      user_id: user_id,
      ean: get_list(product, "p:ean"),
      isbn: get_list(product, "p:isbn"),
      mpn: replace_empty_string(product["p:mpn"]),
      upc: get_list(product, "p:upc"),
      bc_fields: product["bc_fields"],
      parent_sku: parent["sku"],
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      status: "draft",
      is_submitted: false
    }
  end

  defp get_weight_from_string(string) do
    if (weight = Float.parse(string)) != :error do
      elem(weight, 0)
    else
      nil
    end
  end

  defp get_list(data, key) do
    if(data[key] == "",
      do: nil,
      else:
        String.split(
          Regex.replace(~r/(\n|\t|\r)/, data[key], ""),
          ","
        )
    )
  end

  @doc """
      Changing product keys according to its elixir schema.
      E.g. converting to camel or snake case
      and adding data like timestamps for insert_all
  """
  def parse_product_params(data, %{user_id: user_id}) do
    %{
      aspects: replace_empty_string(data["aspects"]),
      condition:
        if(data["producttype"] != "Parent",
          do: replace_empty_string(data["conditionEnum"]) || "NEW_OTHER",
          else: nil
        ),
      description:
        if(data["producttype"] != "Simple",
          do: replace_empty_string(data["description"]),
          else: nil
        ),
      image_ids: replace_empty_string(data["image_ids"]) || [],
      package_weight_and_size: get_package_weight_and_size(data),
      quantity:
        if(data["producttype"] != "Parent",
          do: String.to_integer(data["quantity"]),
          else: nil
        ),
      sku: data["sku"],
      title: replace_empty_string(data["title"]),
      user_id: user_id,
      ean: replace_empty_string(data["ean"]),
      isbn: replace_empty_string(data["isbn"]),
      mpn: replace_empty_string(data["mpn"]),
      upc: replace_empty_string(data["upc"]),
      variant_skus:
        if(data["variantskus"] == "",
          do: nil,
          else:
            String.split(
              Regex.replace(~r/(\n|\t|\r)/, data["variantskus"], ""),
              ","
            )
        ),
      bc_fields: data["bc_fields"],
      aspects_image_varies_by:
        if(data["producttype"] != "Simple",
          do: replace_empty_string([data["imagevariesby"]]),
          else: nil
        ),
      specifications: get_specification(data),
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      status: "draft",
      is_submitted: false
    }
  end

  defp get_specification(product) do
    specs = product["aspectsvariesby"]

    if(product["producttype"] == "Parent" && specs != "") do
      specs = Regex.replace(~r/(\n|\t|\r)/, specs, "")

      ("[" <> specs <> "]")
      |> Jason.decode!()
    else
      []
    end
  end

  defp get_package_weight_and_size(product) do
    if product["producttype"] == "Parent" do
      nil
    else
      %{
        "packageType" => replace_empty_string(product["packagetype"]),
        "weight" => %{
          "value" => replace_empty_string(product["packageweight"]),
          "unit" => "KILOGRAM"
        }
      }
    end
  end

  @doc """
      Changing variation offers keys according to its elixir schema.
      E.g. converting to camel or snake case
      and adding data like timestamps for insert_all
  """
  def form_vo_params(offer, parent_sku, %{user_id: user_id}) do
    %{
      offer_detail: %{
        "storeCategoryNames" => [offer["storecategoryname1"]],
        "marketplaceId" => offer["siteid"],
        "format" => offer["format"],
        "listingDescription" => offer["description"],
        "listingDescriptionTemplateId" => offer["descriptiontemplate"],
        "listingDuration" => "GTC",
        "availableQuantity" => offer["quantity"],
        "pricingSummary" => %{
          "price" => %{"value" => offer["price"], "currency" => offer["currency"]}
        },
        "listingPolicies" => %{
          "fulfillmentPolicyId" => offer["fulfillmentpolicyid"],
          "paymentPolicyId" => offer["paymentpolicyid"],
          "returnPolicyId" => offer["returnpolicyid"]
        },
        "categoryId" => offer["categoryid1"],
        "merchantLocationKey" => offer["merchantlocationkey"],
        "tax" => %{"applyTax" => false, "vatPercentage" => offer["vat"]}
      },
      status: "draft",
      user_id: user_id,
      sku: offer["sku"],
      marketplace_id: offer["siteid"],
      parent_sku: parent_sku,
      is_submitted: false,
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }
  end

  @doc """
      Changing parent offers keys according to its elixir schema.
      E.g. changing to camel or snake case
      and adding data like timestamps for insert_all
  """
  def form_offer_params(offer, %{user_id: user_id}) do
    template = Configurations.get_description_template(%{name: offer["descriptiontemplate"]})

    params = %{
      offer_detail: %{
        "storeCategoryNames" => [offer["storecategoryname1"]],
        "marketplaceId" => offer["siteid"],
        "format" => offer["format"],
        "listingDescription" => offer["description"],
        "listingDescriptionTemplateId" => template && template.id,
        "listingDuration" => "GTC",
        "listingPolicies" => %{
          "fulfillmentPolicyId" => offer["fulfillmentpolicyid"],
          "paymentPolicyId" => offer["paymentpolicyid"],
          "returnPolicyId" => offer["returnpolicyid"]
        },
        "categoryId" => offer["categoryid1"],
        "merchantLocationKey" => offer["merchantlocationkey"],
        "tax" => %{"applyTax" => false, "vatPercentage" => offer["vat"]}
      },
      status: "draft",
      user_id: user_id,
      sku: offer["sku"],
      marketplace_id: offer["siteid"],
      is_submitted: false,
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }

    if(offer["producttype"] == "Simple") do
      update_in(
        params.offer_detail,
        &Map.merge(&1, %{
          "availableQuantity" => offer["quantity"],
          "pricingSummary" => %{
            "price" => %{"value" => offer["price"], "currency" => offer["currency"]}
          }
        })
      )
    else
      params
    end
  end

  @doc """
      To change the field with no data from empty string to nil
  """
  def replace_empty_string(value), do: if(value != "", do: value, else: nil)

  @doc """
      To add an error message to a given map
  """

  def update_error_message(data, msg) do
    if data["error"] in ["", nil], do: msg, else: data["error"] <> ", " <> msg
  end

  @doc """
      To get the skus which are not unique
  """
  def get_duplicate_skus(skus), do: (skus -- Enum.uniq(skus)) |> Enum.uniq()

  @doc """
      Filter out mandatory fields wrt product type
  """
  def get_mandatory_fields(mandatory, product) do
    parent_exception = [
      "categoryid1",
      "price",
      "quantity",
      "conditionid",
      "merchantlocationkey",
      "packagetype",
      "packageweight",
      "storecategoryname1",
      "vat",
      "fulfillmentpolicyid",
      "returnpolicyid",
      "paymentpolicyid"
    ]

    case product["producttype"] do
      "Simple" -> mandatory
      "Parent" -> mandatory -- parent_exception
      _ -> mandatory -- ["title", "description", "images"]
    end
  end

  @doc """
      Convert image urls to ids by adding these to image to ssg database
  """
  def get_image_ids(data, %{user_id: user_id}) do
    urls = String.split(data["images"], ",")
    Enum.map(urls, &create_image_from_url(&1, user_id, "EBAY", data["sku"]).id)
  end

  defp get_fulfillment_ids(site_ids, csr) do
    Enum.reduce(
      site_ids,
      [],
      &(get_policies("fulfillment_policy", csr, &1)["fulfillmentPolicies"] || [] ++ &2)
    )
    |> Enum.map(& &1["fulfillmentPolicyId"])
  end

  defp get_payment_ids(site_ids, csr) do
    Enum.reduce(
      site_ids,
      [],
      &(get_policies("payment_policy", csr, &1)["paymentPolicies"] || [] ++ &2)
    )
    |> Enum.map(& &1["paymentPolicyId"])
  end

  defp get_return_ids(site_ids, csr) do
    Enum.reduce(
      site_ids,
      [],
      &(get_policies("return_policy", csr, &1)["returnPolicies"] || [] ++ &2)
    )
    |> Enum.map(& &1["returnPolicyId"])
  end

  @doc """
      Validate fulfillment policy through ebay api
  """
  def fulfillment_validation(data, fulfillment_ids) do
    if data["fulfillmentpolicyid"] in fulfillment_ids do
      data
    else
      Map.put(data, "error", update_error_message(data, "Invalid value for fulfillment policy"))
    end
  end

  @doc """
      Validate payment policy through ebay api
  """
  def payment_validation(data, payment_ids) do
    if data["paymentpolicyid"] in payment_ids do
      data
    else
      Map.put(data, "error", update_error_message(data, "Invalid value for payment policy"))
    end
  end

  @doc """
      Validate return policy through ebay api
  """
  def return_validation(data, return_ids) do
    if data["returnpolicyid"] in return_ids do
      data
    else
      Map.put(data, "error", update_error_message(data, "Invalid value for return policy"))
    end
  end

  @doc """
      Validate merchant location key against the user
  """
  def merchant_location_key_validation(data, merchant_location_keys) do
    if data["merchantlocationkey"] in merchant_location_keys do
      data
    else
      Map.put(
        data,
        "error",
        update_error_message(data, "Invalid value for merchant location key")
      )
    end
  end

  @doc """
      API to get the required policy from ebay
  """
  def get_policies(policy_name, csr, marketplace_id) do
    with route <-
           Utils.get_route("get_policy") <> "/#{policy_name}?marketplace_id=#{marketplace_id}",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("sell_account"),
             csr
           ),
         {:ok, %OAuth2.Response{body: policies}} <- OAuth2.Client.get(client, route) do
      policies
    end
  end

  @doc """
      To get the all locations under a user
  """
  def get_merchant_locations(csr) do
    with route <- Utils.get_route("get_inventory_location", "EBAY") <> "?limit=100&offset=0",
         client <-
           OauthEbay.session_to_client(
             "Bearer",
             Utils.get_host("inventory", "EBAY"),
             csr
           ),
         {:ok, %OAuth2.Response{body: %{"locations" => locations}}} <-
           OAuth2.Client.get(client, route) do
      Enum.map(locations, & &1["merchantLocationKey"])
    end
  end

  @doc """
      Build an aspects map from random aspects columns starting from c:
  """
  def build_aspects(product) do
    if(product["producttype"] in ["Parent", "Simple"]) do
      %{
        "custom" => %{},
        "dynamic" => build_dynamic_aspects(product)
      }
    else
      build_dynamic_aspects(product)
    end
  end

  def build_dynamic_aspects(product) do
    Enum.reduce(
      product,
      %{},
      fn {key, value}, acc ->
        if(String.contains?(key, "c:") && value != "") do
          Map.put(
            acc,
            String.trim(key, "c:"),
            String.split(
              Regex.replace(~r/(\n|\t|\r)/, value, ""),
              ","
            )
          )
        else
          acc
        end
      end
    )
  end

  def add_error(data, field, comparison_list, msg) do
    Enum.map(
      data,
      &if(&1[field] in comparison_list,
        do: Map.put(&1, "error", &1["error"] <> "," <> msg),
        else: &1
      )
    )
  end

  def update_s3_url(image_params, csr) do
    images =
      Enum.reduce(image_params, [], fn image, acc ->
        case add_images_to_s3(image, csr.user_id) do
          {:ok, resp} -> [put_in(image, [:s3_url], resp) |> put_in([:status], "Success") | acc]
          {:error, _} -> [put_in(image, [:status], "Failed") | acc]
        end
      end)

    success = Enum.filter(images, &(&1.status == "Success"))
    failed = images -- success
    create_bulk_images(Enum.map(success, &Map.drop(&1, [:status, :type])))

    updated_image_ids =
      Enum.map(Enum.uniq_by(failed, & &1.sku), fn %{sku: sku} ->
        target_images =
          Enum.filter(images, fn image ->
            image.sku == sku
          end)

        %{
          sku: sku,
          image_ids:
            Enum.reduce(
              target_images,
              [],
              &if(&1.status == "Success", do: [&1.id | &2], else: &2)
            ),
          type: hd(target_images).type
        }
      end)

    Enum.map(updated_image_ids, fn x ->
      if(x.type == "Simple") do
        from(p in Product, where: p.sku == ^x.sku and p.user_id == ^csr.user_id)
        |> Repo.update_all(set: [image_ids: x.image_ids])
      else
        from(vp in VariationProduct,
          where: vp.sku == ^x.sku and vp.user_id == ^csr.user_id
        )
        |> Repo.update_all(set: [image_ids: x.image_ids])
      end
    end)
  end

  defp add_images_to_s3(image_params, user_id) do
    try do
      url = image_params.s3_url
      %HTTPoison.Response{body: image_binary} = HTTPoison.get!(url)

      file_name = Utils.generate_rand_str() <> Enum.at(String.split(url, "/"), -1)

      unique_filename = "#{Utils.generate_rand_str()}-#{file_name}"
      bucket_name = System.get_env("LISTING_IMAGES_BUCKET", "dev-ebay-sellers-listing-images")

      response =
        ExAws.S3.put_object(bucket_name, "/#{user_id}/" <> unique_filename, image_binary)
        |> ExAws.request!()

      case response do
        %{status_code: 200} ->
          {:ok,
           "https://#{System.get_env("S3_HOST_DOMAIN_URL", "localhost")}/#{bucket_name}/#{user_id}/#{unique_filename}"}

        _ ->
          {:error, image_params.sku}
      end
    rescue
      _ -> {:error, image_params.sku}
    end
  end

  def make_response_identical_to_input_json(data, csr) do
    data
    |> snake_keys_to_camel()
    |> add_required_fields_in_response(csr)
    |> wrap_requested_fields_in_response()
    |> remove_unnecessary_fields_from_response()
  end

  def snake_keys_to_camel(objects) when is_list(objects) do
    Enum.map(objects, &snake_keys_to_camel(&1))
  end

  def snake_keys_to_camel(object) when is_map(object) do
    Enum.reduce(Map.keys(object), %{}, fn
      :variant_skus, acc ->
        val = Map.get(object, :variant_skus)
        Map.merge(acc, %{"variantSKUs" => val})

      key, acc ->
        val = Map.get(object, key)

        cond do
          key in [:__struct__, :__meta__, :user, :product] ->
            acc

          key in [:inserted_at, :updated_at] ->
            Map.merge(acc, %{"#{key}" => val})

          key in [:parent, :variation_products, :variation_offers] ->
            Map.merge(acc, %{key => snake_keys_to_camel(val)})

          key in [:image_ids, :package_weight_and_size] ->
            Map.merge(acc, %{"#{convert_key_to_camel(key)}" => val})

          is_struct(val) ->
            Map.merge(acc, %{"#{key}" => snake_keys_to_camel(val)})

          is_map(val) or is_list(val) ->
            Map.merge(acc, %{"#{key}" => snake_keys_to_camel(val)})

          true ->
            Map.merge(acc, %{"#{key}" => val})
        end
    end)
  end

  def snake_keys_to_camel(non_object_data), do: non_object_data

  def add_required_fields_in_response(data, csr) do
    sku = data[:parent]["sku"]
    offer = Offers.get_offer_listing_id_by_sku(sku, csr)
    listing_id = offer.listing_id

    parent =
      data[:parent]
      |> Map.put("listing_id", listing_id)
      |> Map.put("listingDescriptionTemplateId", offer.template_id)

    Map.merge(data, %{parent: parent})
  end

  def wrap_requested_fields_in_response(data) do
    parent =
      Map.put(data[:parent], "variesBy", %{
        "aspectsImageVariesBy" => Map.get(data[:parent], "aspects_image_varies_by"),
        "specifications" => Map.get(data[:parent], "specifications")
      })

    vp =
      Enum.map(
        data[:variation_products],
        &Map.merge(&1, %{
          "availability" => %{
            "shipToLocationAvailability" => %{"quantity" => Map.get(&1, "quantity")}
          }
        })
      )

    Map.merge(data, %{variation_products: vp, parent: parent})
  end

  def remove_unnecessary_fields_from_response(data) do
    data
    |> pop_in([:parent, "aspects_image_varies_by"])
    |> elem(1)
    |> pop_in([:parent, "specifications"])
    |> elem(1)
    |> pop_in([:parent, "condition"])
    |> elem(1)
    |> pop_in([:parent, "packageWeightAndSize"])
    |> elem(1)
    |> Map.merge(%{
      variation_offers: Enum.map(data[:variation_offers], &Map.delete(&1, "listing_id"))
    })
  end

  def convert_key_to_camel(key) do
    if is_atom(key), do: Recase.to_camel(Atom.to_string(key)), else: Recase.to_camel(key)
  end
end
