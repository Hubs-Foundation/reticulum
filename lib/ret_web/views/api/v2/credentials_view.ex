defmodule RetWeb.Api.V2.CredentialsView do
  use RetWeb, :view

  defp render_credentials(credentials) do
    %{
      id: credentials.api_credentials_sid,
      subject_type: credentials.subject_type,
      is_revoked: credentials.is_revoked,
      scopes: credentials.scopes,
      account_id: credentials.account_id,
      inserted_at: credentials.inserted_at,
      updated_at: credentials.updated_at,
      token: nil
    }
  end

  def render("index.json", %{credentials: credentials}) when is_list(credentials) do
    %{
      credentials: Enum.map(credentials, fn c -> render_credentials(c) end)
    }
  end

  def render("show.json", %{token: token, credentials: credentials}) do
    %{
      credentials: [Map.merge(render_credentials(credentials), %{token: token})]
    }
  end

  def render("show.json", %{credentials: credentials}) do
    render("show.json", %{credentials: credentials, token: nil})
  end

  def render("errors.json", %{errors: errors}) when is_list(errors) do
    %{
      errors: Enum.map(errors, fn e -> render_error(e) end)
    }
  end

  defp render_error({failure_type, message}) do
    %{failure_type: failure_type, message: message}
  end
end
