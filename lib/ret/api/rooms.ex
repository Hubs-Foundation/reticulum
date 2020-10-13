defmodule Ret.Api.Rooms do
  @moduledoc "Functions for accessing rooms in an authenticated way"

  alias Ret.{Account, Hub}
  alias Ret.Api.Scopes

  # App tokens allowed to get any rooms
  def authed_get_rooms_created_by(%Account{} = account, {:reticulum_app_token, scopes}, params) do
    with :ok <- Scopes.ensure_has_scope(scopes, Scopes.read_rooms()) do
      {:ok, Hub.get_my_rooms(account, params)}
    end
  end

  # Account matches resource
  def authed_get_rooms_created_by(%Account{} = account, {account, scopes}, params) do
    with :ok <- Scopes.ensure_has_scope(scopes, Scopes.read_rooms()) do
      {:ok, Hub.get_my_rooms(account, params)}
    end
  end

  def authed_get_rooms_created_by(_, _) do
    {:error, :unauthorized}
  end

  # App tokens allowed to get any rooms
  def authed_get_favorite_rooms_of(%Account{} = account, {:reticulum_app_token, scopes}, params) do
    with :ok <- Scopes.ensure_has_scope(scopes, Scopes.read_rooms()) do
      {:ok, Hub.get_favorite_rooms(account, params)}
    end
  end

  # Account matches resource
  def authed_get_favorite_rooms_of(%Account{} = account, {account, scopes}, params) do
    with :ok <- Scopes.ensure_has_scope(scopes, Scopes.read_rooms()) do
      {:ok, Hub.get_favorite_rooms(account, params)}
    end
  end

  def authed_get_favorite_rooms_of(_, _) do
    {:error, :unauthorized}
  end

  # App tokens allowed to get any rooms
  def authed_get_public_rooms(scopes, params) do
    with :ok <- Scopes.ensure_has_scope(scopes, Scopes.read_rooms()) do
      {:ok, Hub.get_public_rooms(params)}
    end
  end
end
