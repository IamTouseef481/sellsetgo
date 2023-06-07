defmodule EbayXmlApi.UploadSiteHostedPictures do
  @moduledoc false

  import XmlBuilder
  alias EbayXmlApi.XmlUtils

  defstruct FullURL: nil

  @doc """
  <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<UploadSiteHostedPicturesResponse xmlns=\"urn:ebay:apis:eBLBaseComponents\">
     <Timestamp>2022-01-28T13:09:01.314Z</Timestamp>
     <Ack>Success</Ack>
     <Version>0</Version>
     <Build>mediasvcs-5.0.14_20211212182019087</Build>
     <PictureSystemVersion>2</PictureSystemVersion>
     <SiteHostedPictureDetails>
         <PictureName>summa</PictureName>
         <PictureSet>Standard</PictureSet>
         <PictureFormat>JPG</PictureFormat>
         <FullURL>https://i.ebayimg.com/00/s/OTAwWDE0NDA=/z/i3gAAOSwD1Fh8-rt/$_1.JPG?set_id=2</FullURL>
         <BaseURL>https://i.ebayimg.com/00/s/OTAwWDE0NDA=/z/i3gAAOSwD1Fh8-rt/$_</BaseURL>
         <PictureSetMember>
             <MemberURL>https://i.ebayimg.com/00/s/OTAwWDE0NDA=/z/i3gAAOSwD1Fh8-rt/$_1.JPG</MemberURL>
             <PictureHeight>250</PictureHeight>
             <PictureWidth>400</PictureWidth>
         </PictureSetMember>
         <ExternalPictureURL>https://www.ftd.com/blog/wp-content/uploads/2019/02/inspirational-quotes-women-rosalind-russell.jpg</ExternalPictureURL>
         <UseByDate>2022-02-27T13:09:00.623Z</UseByDate>
     </SiteHostedPictureDetails>
     </UploadSiteHostedPicturesResponse>
  """

  def upload_site_hosted_pictures(kw_list) do
    document([
      element(
        :UploadSiteHostedPicturesRequest,
        %{xmlns: "urn:ebay:apis:eBLBaseComponents"},
        kw_list ++
          [
            element(:WarningLevel, "High"),
            element(:ExternalPictureURL, "#{kw_list[:url]}"),
            element(:PictureName, "#{kw_list[:pic_name]}")
          ]
      )
    ])
  end

  def get_upload_pictures(kw_list) do
    body = upload_site_hosted_pictures(kw_list) |> generate

    %{
      body: body,
      call: "UploadSiteHostedPictures",
      com_lvl: 1225,
      size: byte_size(body)
    }
  end

  def get_upload_pictures_response(xml_response) do
    resp_map =
      xml_response
      |> XmlUtils.parse_xml_to_map(:naive)
      |> get_in([:UploadSiteHostedPicturesResponse, :SiteHostedPictureDetails])

    {:ok, struct(__MODULE__, resp_map)}
  end
end
