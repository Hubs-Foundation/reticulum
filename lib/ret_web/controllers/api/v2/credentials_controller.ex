defmodule RetWeb.Api.V2.CredentialsController do
  use RetWeb, :controller

  alias Ret.{Repo}
  alias Ret.Api.Credentials
  alias Ecto.Changeset

  import Ret.Api.TokenUtils,
    only: [to_claims: 2, authed_create_credentials: 2, authed_list_credentials: 2, authed_revoke_credentials: 2]

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  def index(conn, %{"app" => _anything} = _params) do
    IO.puts("inside index 14")
    handle_list_credentials_result(conn, authed_list_credentials(Guardian.Plug.current_resource(conn), :app))
  end


  def index(conn, _params) do
    IO.puts("inside index 19")
    IO.inspect(conn)
    handle_list_credentials_result(conn, authed_list_credentials(Guardian.Plug.current_resource(conn), :account))
  end

  def show(conn, %{"id" => credentials_sid}) do
    IO.puts("inside index 25")

    case Repo.get_by(Credentials, api_credentials_sid: credentials_sid) do
      nil ->
        render_errors(conn, 400, {:error, "Invalid request"})

      credentials ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> put_status(200)
        |> render("show.json", credentials: credentials)
    end
  end

  def create(conn, params) do
    account = Guardian.Plug.current_resource(conn)
    IO.puts("hit create endpoint")

    case to_claims(account, params) do
      {:ok, claims} ->
        handle_create_credentials_result(conn, authed_create_credentials(account, claims))

      {:error, error_list} ->
        render_errors(conn, 400, error_list)
    end
  end

  def update(conn, %{"id" => credentials_sid, "revoke" => _anything}) do
    account = Guardian.Plug.current_resource(conn)

    case Credentials.query()
         |> Credentials.where_sid_is(credentials_sid)
         |> Repo.one() do
      nil ->
        render_errors(conn, 400, {:error, "Invalid request"})

      credentials ->
        handle_revoke_credentials_result(conn, authed_revoke_credentials(account, credentials))
    end
  end

  defp handle_list_credentials_result(conn, {:error, :unauthorized}) do
    render_errors(conn, 401, {:unauthorized, "You do not have permission to view these credentials."})
  end

  defp handle_list_credentials_result(conn, {:error, reason}) do
    render_errors(conn, 400, reason)
  end

  defp handle_list_credentials_result(conn, credentials) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> put_status(200)
    |> render("index.json", credentials: credentials)
  end

  defp handle_create_credentials_result(conn, {:error, :unauthorized}) do
    render_errors(conn, 401, {:unauthorized, "You do not have permission to create these credentials."})
  end

  defp handle_create_credentials_result(conn, {:error, reason}) do
    render_errors(conn, 400, reason)
  end

  defp handle_create_credentials_result(conn, {:ok, token, _claims}) do
    IO.puts("hit handle-credentials-result endpoint")
    # Lookup credentials because token creation returns the
    # claims map, not the credentials object written to DB.
    credentials =
      Credentials.query()
      |> Credentials.where_token_hash_is(Ret.Crypto.hash(token))
      |> Repo.one()

    conn
    |> put_resp_header("content-type", "application/json")
    |> put_status(200)
    |> render("show.json", token: token, credentials: credentials)
  end

  defp handle_revoke_credentials_result(conn, {:error, :unauthorized}) do
    render_errors(conn, 401, {:unauthorized, "You do not have permission to revoke these credentials."})
  end

  defp handle_revoke_credentials_result(conn, {:error, reason}) do
    render_errors(conn, 400, reason)
  end

  defp handle_revoke_credentials_result(conn, {:ok, credentials}) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> put_status(200)
    |> render("show.json", credentials: credentials)
  end

  defp render_errors(conn, status, errors) when is_list(errors) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> put_status(status)
    |> render("errors.json", errors: errors)
  end

  defp render_errors(conn, status, %Changeset{} = changeset) do
    render_errors(conn, status,
      errors: changeset |> Ecto.Changeset.traverse_errors(fn {err, _opts} -> err end) |> Enum.to_list()
    )
  end

  defp render_errors(conn, status, error) do
    render_errors(conn, status, List.wrap(error))
  end
end
