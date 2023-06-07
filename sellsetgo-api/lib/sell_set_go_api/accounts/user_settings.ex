defmodule SellSetGoApi.Accounts.UserSettings do
  @moduledoc """
  The Accounts.UserSettings context.
  """

  import Ecto.Query, warn: false
  alias SellSetGoApi.Repo
  alias SellSetGoApi.Accounts.UserSetting

  def create_user_setting(attrs \\ %{}) do
    %UserSetting{}
    |> UserSetting.changeset(attrs)
    |> Repo.insert(
      conflict_target: [:user_id],
      on_conflict: {:replace, [:notification_settings]},
      returning: [:id]
    )
  end

  def create_if_not_exists(user_id) do
    if(is_nil(get_user_settings(user_id))) do
      create_user_setting(%{user_id: user_id})
    else
      {:ok, ""}
    end
  end

  def get_user_settings(user_id) do
    from(us in UserSetting)
    |> where([up], up.user_id == ^user_id)
    |> Repo.one()
  end

  def update_user_settings(user_id, notification_settings, event_names) do
    settings = get_user_settings(user_id)

    if(is_nil(settings)) do
      create_user_setting(%{user_id: user_id, notification_settings: notification_settings})
    else
      old_settings =
        Enum.filter(settings.notification_settings, &(&1["event"] not in event_names))

      create_user_setting(%{
        user_id: user_id,
        notification_settings: old_settings ++ notification_settings
      })
    end
  end
end
