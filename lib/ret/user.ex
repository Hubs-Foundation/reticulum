defmodule Ret.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ret.User

  @schema_prefix "ret0"
  @primary_key { :user_id, :integer, [] }

  schema "users" do
    field :email, :string
    field :auth_provider, :string
    field :name, :string
    field :first_name, :string
    field :last_name, :string
    field :image, :string

    timestamps()
  end

  @doc false
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:auth_provider])
    |> validate_required([:auth_provider])
  end

  def auth_changeset(%User{} = user, %Ueberauth.Auth{} = auth, attrs \\ %{}) do
    auth_info = Map.take(auth.info, [:email, :name, :first_name, :last_name, :image])

    user
    |> changeset(attrs)
    |> cast(auth_info, [:email, :name, :first_name, :last_name, :image])
    |> validate_required([:email, :auth_provider])
  end
end
