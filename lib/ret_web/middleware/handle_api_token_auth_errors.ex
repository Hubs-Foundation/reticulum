defmodule RetWeb.Middleware.HandleApiTokenAuthErrors do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  def call(%{context: %{api_token_auth_errors: errors}} = resolution, _) when is_list(errors) and length(errors) > 0 do
    {type, reason} = Enum.at(errors, 0)
    put_error_result(resolution, type, reason)
  end

  def call(%{context: %{credentials: nil}} = resolution, _) do
    IO.inspect("no credentials!!")
    put_error_result(resolution, :invalid_credentials, "Could not find credentials for this token.")
  end

  # TODO: Check for expiration
  def call(%{context: %{credentials: %Ret.Api.Credentials{is_revoked: true}}} = resolution, _) do
    put_error_result(resolution, :invalid_credentials, "Token is revoked")
  end

  # I ran into this case in testing. TODO: Figure out why (and if) it's still happening and fix
  def call(resolution, _) do
    put_error_result(resolution, :internal_server_error, "The context was built incorrectly")
  end
end
