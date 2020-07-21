defmodule Ret.RoomQueryHelpers do
  @moduledoc """
  Helpers for building room queries.
  """
  import Ecto.Query

  @doc """
  Main entry point room queries.
  """
  def build_rooms_query(account, params) do
    conditions =
      false
      |> or_is_visible_to_account(account)
      |> maybe_filter_by_favorites(account, params)
      |> maybe_filter_by_public(params)
      |> maybe_filter_by_created(account, params)
      |> maybe_filter_by_room_ids(params)

    Ret.Hub
    |> maybe_join_favorites(account)
    |> where([_hub, _favorite], ^conditions)
  end

  @doc """
  Helper for building queries. Include rooms that are visible to the provided account
  """
  defp or_is_visible_to_account(conditions, account) do
    conditions
    |> or_is_public()
    |> or_is_favorite_of_account(account)
    |> or_is_created_by_account(account)
    |> and_has_entry_mode("allow")
  end

  @doc """
  Helper for building queries. Include rooms favorited by the provided account.
  Assumes AccountFavorites table has been joined to the second slot.
  """
  defp or_is_favorite_of_account(conditions, %Ret.Account{} = _account) do
    dynamic([hub, favorite], not is_nil(favorite) or ^conditions)
  end

  defp or_is_favorite_of_account(conditions, _account) do
    conditions
  end

  @doc """
  Helper for building queries. Include rooms created by the provided account.
  """
  defp or_is_created_by_account(conditions, %Ret.Account{} = account) do
    dynamic([hub], hub.created_by_account_id == ^account.account_id or ^conditions)
  end

  defp or_is_created_by_account(conditions, _account) do
    conditions
  end

  @doc """
  Helper for building queries. Only include rooms created by the provided account.
  """
  defp and_is_created_by_account(conditions, %Ret.Account{} = account) do
    dynamic([hub], hub.created_by_account_id == ^account.account_id and ^conditions)
  end

  defp and_is_created_by_account(_conditions, _account) do
    dynamic([_hub], false)
  end

  defp and_is_not_created_by_account(conditions, %Ret.Account{} = account) do
    dynamic([hub], hub.created_by_account_id != ^account.account_id and ^conditions)
  end

  defp and_is_not_created_by_account(conditions, _account) do
    conditions
  end

  @doc """
  Helper for building queries. Joins the AccountFavorite table to enable queries on favorites
  """
  defp maybe_join_favorites(query, %Ret.Account{} = account) do
    query
    |> join(:left, [h], f in Ret.AccountFavorite, on: f.hub_id == h.hub_id and f.account_id == ^account.account_id)
  end

  defp maybe_join_favorites(query, _account) do
    query
  end

  @doc """
  Helper for building queries. Only include rooms with matching entry mode.
  """
  defp and_has_entry_mode(conditions, entry_mode) do
    dynamic([hub], hub.entry_mode == ^entry_mode and ^conditions)
  end

  @doc """
  Helper for building queries. Optionally restricts results to only include favorites.
  """
  defp maybe_filter_by_favorites(conditions, account, %{"favorites" => "true"}) do
    and_is_favorite_of_account(conditions, account)
  end

  defp maybe_filter_by_favorites(conditions, account, %{"favorites" => true}) do
    and_is_favorite_of_account(conditions, account)
  end

  defp maybe_filter_by_favorites(conditions, account, %{"favorites" => "false"}) do
    and_is_not_favorite_of_account(conditions, account)
  end

  defp maybe_filter_by_favorites(conditions, account, %{"favorites" => false}) do
    and_is_not_favorite_of_account(conditions, account)
  end

  defp maybe_filter_by_favorites(conditions, _account, _params) do
    conditions
  end

  @doc """
  Helper for building queries. Optionally only include or exclude public rooms.
  """
  defp maybe_filter_by_public(conditions, %{"public" => "true"}) do
    and_is_public(conditions)
  end

  defp maybe_filter_by_public(conditions, %{"public" => true}) do
    and_is_public(conditions)
  end

  defp maybe_filter_by_public(conditions, %{"public" => "false"}) do
    and_is_not_public(conditions)
  end

  defp maybe_filter_by_public(conditions, %{"public" => false}) do
    and_is_not_public(conditions)
  end

  defp maybe_filter_by_public(conditions, _params) do
    conditions
  end

  @doc """
  Helper for building queries. Include public rooms.
  """
  defp or_is_public(conditions) do
    dynamic([hub], hub.allow_promotion or ^conditions)
  end

  @doc """
  Helper for building queries. Only include public rooms.
  """
  defp and_is_public(conditions) do
    dynamic([hub], hub.allow_promotion and ^conditions)
  end

  @doc """
  Helper for building queries. Exclude public rooms.
  """
  defp and_is_not_public(conditions) do
    dynamic([hub], not hub.allow_promotion and ^conditions)
  end

  @doc """
  Helper for building queries. Only include rooms favorited by the provided account.
  Assumes AccountFavorites table has been joined to the second slot.
  """
  defp and_is_favorite_of_account(conditions, %Ret.Account{} = _account) do
    dynamic([hub, favorite], not is_nil(favorite) and ^conditions)
  end

  defp and_is_favorite_of_account(_conditions, _account) do
    dynamic([_hub], false)
  end

  @doc """
  Helper for building queries. Exlude rooms favorited by the provided account.
  Assumes AccountFavorites table has been joined to the second slot.
  """
  defp and_is_not_favorite_of_account(conditions, %Ret.Account{} = _account) do
    dynamic([hub, favorite], is_nil(favorite) and ^conditions)
  end

  defp and_is_not_favorite_of_account(conditions, _account) do
    conditions
  end

  @doc """
  Helper for building queries. Optionally only include rooms with the provided ids.
  Assumes AccountFavorites table has been joined to the second slot.
  """
  defp maybe_filter_by_room_ids(conditions, %{"ids" => room_ids}) when is_list(room_ids) do
    dynamic([hub], hub.hub_sid in ^room_ids and ^conditions)
  end

  defp maybe_filter_by_room_ids(conditions, _params) do
    conditions
  end

  @doc """
  Helper for building queries. Optionally only include rooms created by the provided account.
  """
  defp maybe_filter_by_created(conditions, account, %{"created" => "true"}) do
    and_is_created_by_account(conditions, account)
  end

  defp maybe_filter_by_created(conditions, account, %{"created" => true}) do
    and_is_created_by_account(conditions, account)
  end

  defp maybe_filter_by_created(conditions, account, %{"created" => "false"}) do
    and_is_not_created_by_account(conditions, account)
  end

  defp maybe_filter_by_created(conditions, account, %{"created" => false}) do
    and_is_not_created_by_account(conditions, account)
  end

  defp maybe_filter_by_created(conditions, _account, _params) do
    conditions
  end
end
