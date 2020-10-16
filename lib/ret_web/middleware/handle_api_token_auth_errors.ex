defmodule RetWeb.Middleware.HandleApiTokenAuthErrors do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  def call(%{context: %{api_token_auth_errors: errors}} = resolution, _) do
    case length(errors) do
      0 ->
        resolution

      _ ->
        # Just report the first error
        {type, reason} = Enum.at(errors, 0)
        put_error_result(resolution, type, reason)
    end
  end

  # I ran into this case in testing. TODO: Figure out why (and if) it's still happening and fix
  def call(resolution, _) do
    put_error_result(resolution, :internal_server_error, "The context was built incorrectly")
  end
end
