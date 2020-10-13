defmodule RetWeb.Middleware.VerifyToken do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  def call(%{context: %{token: nil}} = resolution, _) do
    put_error_result(
      resolution,
      :api_access_token_not_found,
      "No API Access Token was found in an authorization header."
    )
  end

  def call(%{context: %{token: _token}} = resolution, _) do
    resolution
  end

  def call(resolution, _) do
    put_error_result(
      resolution,
      :api_access_token_not_found,
      "No API Access Token was found in an authorization header."
    )
  end
end
