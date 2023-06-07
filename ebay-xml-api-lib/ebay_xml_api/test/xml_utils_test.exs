defmodule XmlUtilsTest do
  use ExUnit.Case

  alias EbayXmlApi.XmlUtils, as: Xs

  @simple_xml ~s(<AboutUs />)
  @simple_xml_with_attrs ~s(<AboutUs attr1="welcome" attr2="testing" />)
  @simple_xml_with_attrs_and_content ~s(<AboutUs attr1="welcome" attr2="testing">Some Content</AboutUs>)
  @multielement_xml_with_attrs_and_content ~s(<AboutUs attr1="welcome" attr2="testing"><Owner role="superadmin">some user</Owner></AboutUs>)
  @multielement_xml_with_attrs_and_content_and_comment ~s(<AboutUs attr1="welcome" attr2="testing"><Owner role="superadmin">some user</Owner><!--Some Random Comment--></AboutUs>)
  @list_xml ~s(<AboutUs><Person name="user1">User1</Person><Person name="user2">User2</Person></AboutUs>)

  test "parsing_xml_to_map - simple self sufficient xml element" do
    assert Xs.parse_xml_to_map(@simple_xml, :normal) == %{
             "AboutUs" => %{"attrs" => %{}, "content" => []}
           }
  end

  test "parsing_xml_to_map - simple self sufficient xml element with attributes" do
    assert Xs.parse_xml_to_map(@simple_xml_with_attrs, :normal) == %{
             "AboutUs" => %{
               "attrs" => %{"attr1" => "welcome", "attr2" => "testing"},
               "content" => []
             }
           }
  end

  test "parsing_xml_to_map - simple self sufficient xml element with attributes and content" do
    assert Xs.parse_xml_to_map(@simple_xml_with_attrs_and_content, :normal) == %{
             "AboutUs" => %{
               "attrs" => %{"attr1" => "welcome", "attr2" => "testing"},
               "content" => ["Some Content"]
             }
           }
  end

  test "parsing_xml_to_map - multi element xml with attributes and content" do
    assert Xs.parse_xml_to_map(@multielement_xml_with_attrs_and_content, :normal) == %{
             "AboutUs" => %{
               "attrs" => %{"attr1" => "welcome", "attr2" => "testing"},
               "content" => [
                 %{"Owner" => %{"attrs" => %{"role" => "superadmin"}, "content" => ["some user"]}}
               ]
             }
           }
  end

  test "parsing_xml_to_map - multi element xml with attributes, content and comment" do
    assert Xs.parse_xml_to_map(@multielement_xml_with_attrs_and_content_and_comment, :normal) ==
             %{
               "AboutUs" => %{
                 "attrs" => %{"attr1" => "welcome", "attr2" => "testing"},
                 "content" => [
                   %{
                     "Owner" => %{
                       "attrs" => %{"role" => "superadmin"},
                       "content" => ["some user"]
                     }
                   },
                   %{"comment" => %{"content" => ["Some Random Comment"]}}
                 ]
               }
             }
  end

  test "parsing_xml_to_map - xml with list of same elements" do
    assert Xs.parse_xml_to_map(@list_xml, :normal) == %{
             "AboutUs" => %{
               "attrs" => %{},
               "content" => [
                 %{"Person" => %{"attrs" => %{"name" => "user1"}, "content" => ["User1"]}},
                 %{"Person" => %{"attrs" => %{"name" => "user2"}, "content" => ["User2"]}}
               ]
             }
           }
  end

  test "parsing_xml_to_naive_map - simple self sufficient xml element" do
    assert Xs.parse_xml_to_map(@simple_xml, :naive) == %{AboutUs: %{}}
  end

  test "parsing_xml_to_naive_map - simple self sufficient xml element with attributes" do
    assert Xs.parse_xml_to_map(@simple_xml_with_attrs, :naive) == %{AboutUs: %{}}
  end

  test "parsing_xml_to_naive_map - simple self sufficient xml element with attributes and content" do
    assert Xs.parse_xml_to_map(@simple_xml_with_attrs_and_content, :naive) == %{
             AboutUs: "Some Content"
           }
  end

  test "parsing_xml_to_naive_map - multi element xml with attributes and content" do
    assert Xs.parse_xml_to_map(@multielement_xml_with_attrs_and_content, :naive) == %{
             AboutUs: %{Owner: "some user"}
           }
  end

  test "parsing_xml_to_naive_map - multi element xml with attributes, content and comment" do
    assert Xs.parse_xml_to_map(@multielement_xml_with_attrs_and_content_and_comment, :naive) == %{
             AboutUs: %{Owner: "some user"}
           }
  end

  test "parsing_xml_to_naive_map - xml with list of same elements" do
    assert Xs.parse_xml_to_map(@list_xml, :naive) == %{AboutUs: %{Person: ["User1", "User2"]}}
  end
end
