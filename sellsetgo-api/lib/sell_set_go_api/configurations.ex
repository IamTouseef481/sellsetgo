defmodule SellSetGoApi.Configurations do
  @moduledoc """
  This module contains the common configuration for the SellSetGoApi.
  """

  alias SellSetGoApi.Accounts.{DescriptionTemplate, GlobalTemplateTag, Users}
  alias SellSetGoApi.Inventory.Products
  alias SellSetGoApi.{Feedbacks, Listings, Repo, Utils}
  import Ecto.Query

  def create_description_templates(attrs) do
    attrs = form_description_templates_attrs(attrs)

    %DescriptionTemplate{}
    |> DescriptionTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def update_description_templates(%{"id" => id, "user_id" => user_id} = attrs) do
    attrs = form_description_templates_attrs(attrs)
    description_template = get_description_template(%{id: id, user_id: user_id})

    description_template
    |> DescriptionTemplate.changeset(attrs)
    |> Repo.update()
  end

  def get_global_template_tags(user_id) do
    Repo.get_by(GlobalTemplateTag, user_id: user_id)
  end

  def get_description_template(criteria) do
    Repo.get_by(DescriptionTemplate, criteria)
  end

  def list_description_templates(user_id) do
    from(dt in DescriptionTemplate,
      where: dt.user_id == ^user_id
    )
    |> Repo.all()
  end

  def list_description_template_names(user_id) do
    from(dt in DescriptionTemplate,
      select: %{name: dt.name, id: dt.id},
      where: dt.user_id == ^user_id
    )
    |> Repo.all()
  end

  def update_global_template_tags(tags, params) do
    tags
    |> GlobalTemplateTag.changeset(params)
    |> Repo.update()
  end

  def compute_description_template(user_id, offer, sku) do
    case offer["listingDescriptionTemplateId"] do
      nil ->
        offer["listingDescription"]

      _desc_id ->
        stitch_description_template(user_id, offer, sku)
    end
  end

  def stitch_description_template(
        user_id,
        %{"listingDescriptionTemplateId" => desc_id} = offer,
        sku
      ) do
    product = Products.get_product_by_sku(sku, %{user_id: user_id})

    image_urls =
      Map.get(product, :image_ids)
      |> Listings.get_provider_image_urls_from_ids(user_id)

    listing_description = get_description_template(%{user_id: user_id, id: desc_id}).template

    keys = get_keys_list_from_description_template(listing_description)
    global_tags = get_global_template_tags(user_id).template_tags

    Enum.reduce(keys, listing_description, fn key, acc ->
      cond do
        key in ["price", "ebaycategory1", "storecategory1", "description", "ebay_itemid"] ->
          replace_wrt_offer_keys(key, acc, offer)

        key == "title" ->
          replace_string_with_value(acc, key, Map.get(product, :title))

        key == "sku" ->
          replace_string_with_value(acc, key, sku)

        key in ["about", "payment", "shipping", "returns", "contact"] ->
          replace_global_tags(key, global_tags, acc)

        String.contains?(key, "image") ->
          replace_string_with_value("image", acc, key, image_urls)

        true ->
          replace_template_tags(key, acc, offer, product)
      end
    end)
  end

  def get_keys_list_from_description_template(description) do
    Regex.scan(~r{\{\{.*?\}\}}, description)
    |> List.flatten()
    |> Enum.map(fn x -> String.trim_leading(x, "{") |> String.trim_trailing("}") end)
  end

  def delete_description_template(%DescriptionTemplate{} = description_template) do
    Repo.delete(description_template)
  end

  defp replace_wrt_offer_keys(key, description, offer) do
    cond do
      key == "price" ->
        price = get_in(offer, ["pricingSummary", "price"])

        replace_string_with_value(
          description,
          key,
          "#{price["value"]}" <> " #{price["currency"]}"
        )

      key == "ebaycategory1" ->
        replace_string_with_value(description, key, offer["categoryId"])

      key == "storecategory1" ->
        store_cat_names = List.first(offer["storeCategoryNames"])

        replace_string_with_value(description, key, store_cat_names)

      key == "description" ->
        replace_string_with_value(description, key, offer["listingDescription"])

      key == "ebay_itemid" ->
        replace_string_with_value(description, key, offer["listing_id"])
    end
  end

  defp replace_global_tags(key, global_tags, description) do
    Enum.reduce(global_tags, description, fn %{tag: tag, value: value}, acc ->
      if tag == key do
        replace_string_with_value(acc, key, value)
      else
        acc
      end
    end)
  end

  defp replace_string_with_value(string, key, nil) do
    String.replace(string, "{{#{key}}}", "")
  end

  defp replace_string_with_value(string, key, value) do
    String.replace(string, "{{#{key}}}", value)
  end

  defp replace_string_with_value("image", string, key, urls) do
    index = (String.trim_leading(key, "image") |> String.to_integer()) - 1
    replace_string_with_value(string, key, Enum.at(urls, index))
  end

  def form_description_templates_attrs(attrs) do
    template =
      HtmlSanitizeEx.Scrubber.scrub(attrs["template"] || "", SellSetGoApi.Html5Scrubber)
      |> String.replace("<></>", "")

    Map.put(attrs, "template", template)
  end

  def replace_template_tags("itemspecifics", description, _offer, product) do
    aspects = Map.get(product, :aspects)

    aspects =
      case Map.get(aspects, "custom") do
        nil ->
          aspects

        custom ->
          Map.get(aspects, "dynamic", %{}) |> Map.merge(custom)
      end
      |> then(fn aspect ->
        case Map.get(aspect, "dynamic") do
          nil ->
            aspect

          dynamic ->
            dynamic
        end
      end)

    aspects =
      "<ul>" <>
        Enum.reduce(aspects, "", fn {key, values}, acc ->
          acc <>
            "<li><span> #{key}: </span>" <>
            (Enum.reduce(values || [], "", fn value, acc1 ->
               acc1 <> ",<span>#{value}<span>"
             end)
             |> String.trim_leading(",")) <> "</li>"
        end) <> "</ul>"

    replace_string_with_value(description, "itemspecifics", aspects)
  end

  def replace_template_tags(
        "storecategories",
        description,
        %{"marketplaceId" => marketplace_id},
        %{user_id: user_id}
      ) do
    domain = Utils.get_domain(marketplace_id)

    %{store_name: store_name, categories: categories} =
      Users.show_store_categories(user_id)
      |> List.first()
      |> case do
        nil -> %{store_name: "", categories: %{}}
        store_cate -> store_cate
      end

    store_categories_template(categories["custom_category"], domain, store_name)
    |> then(fn store_categories ->
      replace_string_with_value(description, "storecategories", store_categories)
    end)
  end

  def replace_template_tags(
        "newarrivals",
        description,
        %{"marketplaceId" => marketplace_id},
        %{user_id: user_id}
      ) do
    with {:ok, %{domain: domain, currency_symbol: currency_symbol}} <-
           Utils.get_ebay_details(marketplace_id) do
      new_arrivals =
        "<ul>" <>
          (Products.get_new_arrivals(user_id, marketplace_id)
           |> Enum.reduce("", fn item, acc ->
             image_url = Enum.at(item.image_ids, 0) |> Listings.get_image_by_id(user_id)

             acc <>
               "<li><div class=”widget_image”><img src=#{image_url}></div><div class=”widget_title”>
               <a href=\"https://www.#{domain}/itm/#{item.listing_id}\"> #{item.title}</a>
               </div>" <>
               "<div class=”widget_price”>#{currency_symbol} #{item.price}</div>" <>
               "<div class=”widget_buynow”><a href=\"https://www.#{domain}/itm/#{item.listing_id}\"> BUY NOW </a></div></li>"
           end)) <> "</ul>"

      replace_string_with_value(description, "newarrivals", new_arrivals)
    end
  end

  def replace_template_tags("recentfeedback", description, _offer, %{user_id: user_id}) do
    feedbacks = Feedbacks.list_feedbacks(user_id)

    feedbacks =
      "<ul>" <>
        Enum.reduce(feedbacks, "", fn feedback, acc ->
          acc <>
            "<li><div><div class=\"feedback_text\">#{feedback.comment_text}</div>" <>
            "<div class=\"item_title\">#{feedback.item_title}</div>" <>
            "<div class=\"item_id\">#{feedback.item_id}</div></div>" <>
            "<div><div class=\"buyer_name\">#{feedback.commenting_user_id}</div>" <>
            "<div class=\"buyer_score\">(#{feedback.commenting_user_score}</div>" <>
            "<div class=\"#{feedback.feedback_rating_star}\"> ) </div>" <>
            "<div class=\"item_price\">#{feedback.currency_symbol}</div>" <>
            "<div class=\"item_price\">#{feedback.price}</div></div>" <>
            "<div><div class=\"item_price\">#{feedback.comment_time}</div></div></li>"
        end) <> "</ul>"

    replace_string_with_value(description, "recentfeedback", feedbacks)
  end

  def replace_template_tags(
        "relateditems",
        description,
        %{"marketplaceId" => marketplace_id, "storeCategoryNames" => store_categories},
        %{user_id: user_id}
      ) do
    with {:ok, %{domain: domain, currency_symbol: currency_symbol}} <-
           Utils.get_ebay_details(marketplace_id) do
      related_items =
        "<ul>" <>
          (Products.get_related_items(user_id, marketplace_id, List.first(store_categories))
           |> Enum.reduce("", fn item, acc ->
             image_url = Enum.at(item.image_ids, 0) |> Listings.get_image_by_id(user_id)

             acc <>
               "<li><div class=”widget_image”><img src=#{image_url}></div><div class=”widget_title”>
               <a href=\"https://www.#{domain}/itm/#{item.listing_id}\"> #{item.title}</a>
               </div>" <>
               "<div class=”widget_price”>#{currency_symbol} #{item.price}</div>" <>
               "<div class=”widget_buynow”><a href=\"https://www.#{domain}/itm/#{item.listing_id}\"> BUY NOW </a></div></li>"
           end)) <> "</ul>"

      replace_string_with_value(description, "relateditems", related_items)
    end
  end

  def replace_template_tags(_, acc, _offer, _product) do
    acc
  end

  defp store_categories_template([], _domain, _store_name), do: ""

  defp store_categories_template(nil, _domain, _store_name), do: ""

  defp store_categories_template(store_categories, domain, store_name) do
    "<ul>" <>
      Enum.reduce(store_categories, "", fn category, acc ->
        acc <>
          "<li><a href=\"#{domain}/str/#{store_name}?store_cat=#{category["category_id"]}\">#{category["name"]}</a>#{store_categories_template(category["child_categories"], domain, store_name)}</li>"
      end) <> "</ul>"
  end

  @doc """
  Strips all comments.
  """
  defmacro allow_comments do
    quote do
      def scrub({:comment, children} = test), do: test
    end
  end
end
