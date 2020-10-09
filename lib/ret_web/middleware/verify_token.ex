defmodule RetWeb.Middleware.VerifyToken do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.AuthErrorUtil, only: [put_error_result: 3]

  def call(%{context: %{auth_error: {_type, :token_not_found}}} = resolution, _) do
    # TODO: Maybe not say revoked. Just token not found.
    put_error_result(resolution, :auth_error_token_was_revoked, "The api token has been revoked.")
  end

  def call(%{context: %{auth_error: {type, reason}}} = resolution, _) do
    put_error_result(resolution, type, reason)
  end

  def call(%{context: %{token: nil}} = resolution, _) do
    put_error_result(
      resolution,
      :auth_error_token_is_missing,
      "Missing api token in authorization header required for access"
    )
  end

  def call(resolution, _) do
    resolution
  end
end
