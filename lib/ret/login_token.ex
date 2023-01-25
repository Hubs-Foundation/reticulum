defmodule Ret.LoginToken do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Repo, Account}

  @schema_prefix "ret0"
  @primary_key {:login_token_id, :id, autogenerate: true}
  @token_max_age 1_800

  schema "login_tokens" do
    field :token, :string
    field :payload_key, :string
    field :identifier_hash, :string

    timestamps()
  end

  @doc false
  def changeset_for_email(login_token, email) do
    token = generate_token(email)

    login_token
    |> cast(%{}, [])
    |> put_change(:token, token)
    |> put_change(:payload_key, SecureRandom.hex())
    |> put_change(:identifier_hash, email |> Account.identifier_hash_for_email())
    |> validate_required([:token, :identifier_hash])
  end

  def new_login_token_for_email(email) do
    %Ret.LoginToken{}
    |> changeset_for_email(email)
    |> Repo.insert!()
  end

  def lookup_by_token(token) do
    login_token =
      Repo.one(
        from t in Ret.LoginToken,
          where: t.token == ^token,
          where:
            t.inserted_at >
              datetime_add(^NaiveDateTime.utc_now(), ^(@token_max_age * -1), "second")
      )

    if login_token do
      login_token
    else
      nil
    end
  end

  def expire(token) do
    Repo.delete_all(from t in Ret.LoginToken, where: t.token == ^token)
  end

  def expire_stale do
    Ret.Locking.exec_if_lockable(:login_token_expire, fn ->
      Repo.delete_all(
        from t in Ret.LoginToken,
          where:
            t.inserted_at <
              datetime_add(^NaiveDateTime.utc_now(), ^(@token_max_age * -1), "second")
      )
    end)
  end

  defp generate_token(nil), do: nil

  defp generate_token(_email) do
    SecureRandom.hex()
  end
end
