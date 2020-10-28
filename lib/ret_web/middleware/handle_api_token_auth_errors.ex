defmodule RetWeb.Middleware.HandleApiTokenAuthErrors do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  # Don't enforce tokens on introspection queries
  # Source: Absinthe.Introspection.type?
  # https://github.com/absinthe-graphql/absinthe/blob/cdb8c39beb6a79b03a5095fffbe761e0dd9918ac/lib/absinthe/introspection.ex#L106
  def call(%{parent_type: %{name: "__" <> _}} = resolution, _) do
    resolution
  end

  def call(%{context: %{api_token_auth_errors: errors}} = resolution, _) when is_list(errors) and length(errors) > 0 do
    {type, reason} = Enum.at(errors, 0)
    put_error_result(resolution, type, reason)
  end

  def call(%{context: %{credentials: nil}} = resolution, _) do
    put_error_result(
      resolution,
      :api_access_token_not_found,
      "Failed to find api access token when searching for header 'Authorization: Bearer <your_api_access_token>'"
    )
  end

  def call(%{context: %{credentials: %Ret.Api.Credentials{is_revoked: true}}} = resolution, _) do
    put_error_result(resolution, :invalid_credentials, "Token is revoked")
  end

  def call(%{context: %{credentials: %Ret.Api.Credentials{expires_at: expires_at}}} = resolution, _) do
    if Timex.before?(expires_at, Timex.now()) do
      put_error_result(resolution, :token_expired, "Token expired")
    else
      resolution
    end
  end

  # # TODO: Remove
  # def call(resolution, _) do
  #   put_error_result(resolution, :unknown_server_error, "Could not validate token/credentials")
  # end
end
