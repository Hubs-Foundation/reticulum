defmodule Ret.AccountHubFavorite do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Hub, Account, AccountHubFavorite, Repo}

  @schema_prefix "ret0"
  @primary_key {:account_hub_favorite_id, :id, autogenerate: true}

  schema "account_hub_favorites" do
    belongs_to(:account, Ret.Account, references: :account_id)
    belongs_to(:hub, Ret.Hub, references: :hub_id)
    field(:last_joined_at, :utc_datetime)

    timestamps()
  end

  # Returns true if a favorite existed, false otherwise.
  # As a side effect, timestamps the join on the favorite.
  def timestamp_join_if_favorited(%Hub{} = hub, %Account{} = account) do
    favorite = get_favorite(hub, account)

    if favorite do
      favorite |> changeset_for_join |> Repo.update!()
      true
    else
      false
    end
  end

  def ensure_favorited(%Hub{} = hub, %Account{} = account) do
    favorite = get_favorite(hub, account)

    if favorite == nil do
      %AccountHubFavorite{} |> changeset(hub, account) |> Repo.insert()
    end
  end

  def ensure_favorited(%Hub{}, nil), do: nil

  def ensure_not_favorited(%Hub{} = hub, %Account{} = account) do
    favorite = get_favorite(hub, account)

    if favorite do
      Repo.delete(favorite)
    end
  end

  def ensure_not_favorited(%Hub{}, nil), do: nil

  # Create a favorite
  defp changeset(%AccountHubFavorite{} = favorite, hub, account) do
    favorite
    |> change()
    |> put_assoc(:hub, hub)
    |> put_assoc(:account, account)
    |> put_change(:last_joined_at, Timex.now())
  end

  defp changeset_for_join(%AccountHubFavorite{} = favorite) do
    favorite
    |> change()
    |> put_change(:last_joined_at, Timex.now())
  end

  defp get_favorite(%Hub{}, nil), do: nil

  defp get_favorite(%Hub{} = hub, %Account{} = account) do
    AccountHubFavorite |> Repo.get_by(account_id: account.account_id, hub_id: hub.hub_id)
  end
end
