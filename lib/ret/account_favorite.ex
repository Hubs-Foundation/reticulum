defmodule Ret.AccountFavorite do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Hub, Account, AccountFavorite, Repo}

  @schema_prefix "ret0"
  @primary_key {:account_favorite_id, :id, autogenerate: true}

  schema "account_favorites" do
    field :last_activated_at, :utc_datetime

    belongs_to :account, Ret.Account, references: :account_id
    belongs_to :hub, Ret.Hub, references: :hub_id

    timestamps()
  end

  def timestamp_join_if_favorited(%Hub{}, nil), do: false

  # Returns true if a favorite existed, false otherwise.
  # As a side effect, timestamps the join on the favorite.
  def timestamp_join_if_favorited(%Hub{} = hub, %Account{} = account) do
    favorite = get_favorite(hub, account)

    if favorite do
      favorite |> changeset_for_activation |> Repo.update!()
      true
    else
      false
    end
  end

  def ensure_favorited(%Hub{} = hub, %Account{} = account) do
    favorite = get_favorite(hub, account)

    if favorite == nil do
      {:ok, new_favorite} = %AccountFavorite{} |> changeset(hub, account) |> Repo.insert()
      new_favorite
    else
      favorite
    end
  end

  def ensure_favorited(%Hub{}, nil), do: nil

  def ensure_not_favorited(%Hub{} = hub, %Account{} = account) do
    favorite = get_favorite(hub, account)

    if favorite do
      Repo.delete(favorite)
      true
    else
      false
    end
  end

  def ensure_not_favorited(%Hub{}, nil), do: nil

  # Create a favorite
  defp changeset(%AccountFavorite{} = favorite, hub, account) do
    favorite
    |> change()
    |> put_assoc(:hub, hub)
    |> put_assoc(:account, account)
    |> put_change(:last_activated_at, Timex.now() |> DateTime.truncate(:second))
  end

  defp changeset_for_activation(%AccountFavorite{} = favorite) do
    favorite
    |> change()
    |> put_change(:last_activated_at, Timex.now() |> DateTime.truncate(:second))
  end

  defp get_favorite(%Hub{}, nil), do: nil

  defp get_favorite(%Hub{} = hub, %Account{} = account) do
    AccountFavorite |> Repo.get_by(account_id: account.account_id, hub_id: hub.hub_id)
  end
end
