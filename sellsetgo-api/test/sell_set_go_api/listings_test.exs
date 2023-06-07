defmodule SellSetGoApi.ListingsTest do
  use SellSetGoApi.DataCase

  alias SellSetGoApi.Listings

  # describe "images" do
  #   alias SellSetGoApi.Listings.Image

  #   @valid_attrs %{provider: "some provider", provider_image_url: "some provider_image_url", s3_url: "some s3_url"}
  # @update_attrs %{
  #   provider: "some updated provider",
  #   provider_image_url: "some updated provider_image_url",
  #   s3_url: "some updated s3_url"
  # }
  #   @invalid_attrs %{provider: nil, provider_image_url: nil, s3_url: nil}

  #   def image_fixture(attrs \\ %{}) do
  #     {:ok, image} =
  #       attrs
  #       |> Enum.into(@valid_attrs)
  #       |> Listings.create_image()

  #     image
  #   end

  #   test "list_images/0 returns all images" do
  #     image = image_fixture()
  #     assert Listings.list_images() == [image]
  #   end

  #   test "get_image!/1 returns the image with given id" do
  #     image = image_fixture()
  #     assert Listings.get_image!(image.id) == image
  #   end

  #   test "create_image/1 with valid data creates a image" do
  #     assert {:ok, %Image{} = image} = Listings.create_image(@valid_attrs)
  #     assert image.provider == "some provider"
  #     assert image.provider_image_url == "some provider_image_url"
  #     assert image.s3_url == "some s3_url"
  #   end

  #   test "create_image/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Listings.create_image(@invalid_attrs)
  #   end

  #   test "update_image/2 with valid data updates the image" do
  #     image = image_fixture()
  #     assert {:ok, %Image{} = image} = Listings.update_image(image, @update_attrs)
  #     assert image.provider == "some updated provider"
  #     assert image.provider_image_url == "some updated provider_image_url"
  #     assert image.s3_url == "some updated s3_url"
  #   end

  #   test "update_image/2 with invalid data returns error changeset" do
  #     image = image_fixture()
  #     assert {:error, %Ecto.Changeset{}} = Listings.update_image(image, @invalid_attrs)
  #     assert image == Listings.get_image!(image.id)
  #   end

  #   test "delete_image/1 deletes the image" do
  #     image = image_fixture()
  #     assert {:ok, %Image{}} = Listings.delete_image(image)
  #     assert_raise Ecto.NoResultsError, fn -> Listings.get_image!(image.id) end
  #   end

  #   test "change_image/1 returns a image changeset" do
  #     image = image_fixture()
  #     assert %Ecto.Changeset{} = Listings.change_image(image)
  #   end
  # end
end
