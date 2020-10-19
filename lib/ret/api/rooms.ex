defmodule Ret.Api.Rooms do
  @moduledoc "Functions for accessing rooms in an authenticated way"

  alias Ret.{Account, Hub}
  alias Ret.Api.{Credentials}

  import Canada, only: [can?: 2]

  # App tokens allowed to get any rooms
  def authed_get_rooms_created_by(%Account{} = account, %Credentials{} = credentials, params) do
    if can?(credentials, get_rooms_created_by(account)) do
      {:ok, Hub.get_my_rooms(account, params)}
    else
      {:error, :invalid_credentials}
    end
  end

  def authed_get_favorite_rooms_of(%Account{} = account, %Credentials{} = credentials, params) do
    if can?(credentials, get_favorite_rooms_of(account)) do
      {:ok, Hub.get_my_rooms(account, params)}
    else
      {:error, :invalid_credentials}
    end
  end

  def authed_get_public_rooms(%Credentials{} = credentials, params) do
    if can?(credentials, get_public_rooms(nil)) do
      {:ok, Hub.get_public_rooms(params)}
    else
      {:error, :invalid_credentials}
    end
  end
end
