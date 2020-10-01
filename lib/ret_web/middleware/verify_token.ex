defmodule RetWeb.Middleware.VerifyToken do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.AuthErrorUtil, only: [return_error: 3]

  def call(%{context: %{auth_error: {_type, :token_not_found}}} = resolution, _) do
    return_error(resolution, :auth_error_token_was_revoked, "The api token has been revoked.")
  end

  def call(%{context: %{auth_error: {type, reason}}} = resolution, _) do
    return_error(resolution, type, reason)
  end

  def call(%{context: %{token: nil}} = resolution, _) do
    return_error(
      resolution,
      :auth_error_token_is_missing,
      "Missing api token in authorization header required for access"
    )
  end

  def call(resolution, _) do
    resolution
  end
end
