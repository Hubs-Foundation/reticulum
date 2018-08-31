defmodule Ret.Account do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Repo, Account, Login}

  @schema_prefix "ret0"
  @primary_key {:account_id, :id, autogenerate: true}

  schema "accounts" do
    has_one(:login, Ret.Login, foreign_key: :account_id)
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [])
    |> validate_required([])
  end

  def account_for_email(email) do
    login =
      Login
      |> where([t], t.email == ^email)
      |> Repo.one()

    if login do
      Account |> Repo.get(login.account_id) |> Repo.preload(:login)
    else
      Repo.insert!(%Account{login: %Login{email: email}})
    end
  end
end
