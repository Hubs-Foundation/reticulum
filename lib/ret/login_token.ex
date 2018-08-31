defmodule Ret.LoginToken do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Phoenix.Token
  alias Ret.Repo

  @schema_prefix "ret0"
  @primary_key {:login_token_id, :id, autogenerate: true}
  @token_max_age 1_800

  schema "login_tokens" do
    field(:token, :string)

    timestamps()
  end

  @doc false
  def changeset_for_email(login_token, email) do
    token = generate_token(email)

    login_token
    |> cast(%{}, [])
    |> put_change(:token, token)
    |> validate_required([:token])
  end

  def new_token_for_email(email) do
    %Ret.LoginToken{}
    |> changeset_for_email(email)
    |> Repo.insert!()
    |> Map.get(:token)
  end

  def valid_email_for_token(token) do
    with %Ret.LoginToken{} <- Repo.get_by(Ret.LoginToken, token: token) do
      token_check = Token.verify(RetWeb.Endpoint, "login_token", token, max_age: @token_max_age)

      case token_check do
        {:ok, email} -> email
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  def expire!(token) do
    Ret.LoginToken
    |> where([t], t.token == ^token)
    |> Repo.delete_all()
  end

  defp generate_token(nil), do: nil

  defp generate_token(email) do
    Token.sign(RetWeb.Endpoint, "login_token", email)
  end
end
