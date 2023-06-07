defmodule SellSetGoApi.Accounts.GlobalTemplateTag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias SellSetGoApi.Accounts.GlobalTemplateTag.Tag

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  schema "global_template_tags" do
    embeds_many(:template_tags, Tag, on_replace: :delete)
    belongs_to(:user, SellSetGoApi.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:user_id])
    |> cast_embed(:template_tags)
  end
end

defmodule SellSetGoApi.Accounts.GlobalTemplateTag.Tag do
  @moduledoc false
  use Ecto.Schema
  require Protocol
  import Ecto.Changeset

  # These to lines are used to get the app name from mix.exs
  line = "mix.exs" |> File.stream!() |> Enum.take(1)
  [app_name | _] = Regex.run(~r/(\S+)(?=\.)/, to_string(line))

  @primary_key false
  embedded_schema do
    field(:tag, :string)
    field(:value, :string)
    field(:type, :string)
    field(:created_by, :string, default: app_name)
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:tag, :value, :type, :created_by])
    |> validate_inclusion(:type, ~w(text html number date time))
    |> validate_tag_values_by_types()
  end

  defp validate_tag_values_by_types(%{changes: tag} = changeset) do
    value = HtmlSanitizeEx.markdown_html(tag[:value] || "")
    put_change(changeset, :value, value)
  end

  Protocol.derive(Jason.Encoder, SellSetGoApi.Accounts.GlobalTemplateTag.Tag,
    only: [:tag, :type, :value]
  )
end
