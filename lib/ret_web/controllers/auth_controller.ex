defmodule RetWeb.AuthController do
  use RetWeb, :controller

  plug Ueberauth

  alias Ret.User
  alias Ret.Repo

  alias RetWeb.Router.Helpers

  def request(_, _) do
  end

  def unauthenticated(conn, _) do
    redirect(conn, to: Helpers.auth_path(conn, :request, :google))
  end

  def callback(%{ assigns: %{ ueberauth_failure: _failure }} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: Helpers.page_path(conn, :index))
  end

  def callback(%{ assigns: %{ ueberauth_auth: auth }} = conn, _params) do
    perform_login(conn, Repo.get_by(User, email: auth.info.email), auth)
  end

  defp perform_login(conn, nil, %Ueberauth.Auth{} = auth) do
    changeset = User.auth_changeset(%User{}, auth, %{ auth_provider: "google" })
    case Repo.insert(changeset) do
      { :ok, _user } ->
        conn #have to fetch the user again because the insert is not returning a user_id
        |> perform_login(Repo.get_by(User, email: auth.info.email), auth)
      { :error, _reason } ->
        conn
        |> json(%{ status: :error })
    end  
  end

  defp perform_login(conn, %User{} = user, %Ueberauth.Auth{} = _auth) do
    get_format(conn) |> handle_login(conn, user)
  end

  defp handle_login("html" = _format, conn, %User{} = user) do
    conn = conn
    |> Guardian.Plug.sign_in(user)
    |> put_flash(:info, "Authenticated successfully.")

    {:ok, jwt, claims} = 
      Guardian.Plug.current_resource(conn) 
      |> Guardian.encode_and_sign(%{email: user.email})

    conn
    |> put_resp_cookie("jwt", jwt, http_only: false)
    |> redirect(to: Helpers.client_path(conn, :index))
  end

  defp handle_login("json" = _format, conn, %User{} = user) do
    conn = Guardian.Plug.api_sign_in(conn, user)
    jwt = Guardian.Plug.current_token(conn)

    conn
    |> put_resp_header("authorization", "Bearer #{jwt}")
    |> json(%{ status: :OK, access_token: jwt })
  end

end
