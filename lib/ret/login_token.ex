defmodule Ret.LoginToken do
  use Ecto.Schema
  import Ecto.Changeset

  alias Phoenix.Token

  @schema_prefix "ret0"
  @primary_key {:login_token_id, :integer, []}

  schema "login_tokens" do
    field(:email, :string)
    field(:token, :string)

    timestamps()
  end

  @doc false
  def changeset(login_token, attrs) do
    token = generate_token(attrs[:email])

    login_token
    |> cast(attrs, [:email])
    |> put_change(:token, token)
    |> validate_required([:token, :email])
  end

  defp generate_token(nil), do: nil

  defp generate_token(email) do
    Token.sign(RetWeb.Endpoint, "login_token", email)
  end
end
