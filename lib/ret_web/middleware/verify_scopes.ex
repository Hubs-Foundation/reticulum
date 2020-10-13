defmodule RetWeb.Middleware.VerifyScopes do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  # TODO: Should an :api scope be required to make any requests to the api?
  def call(%{context: %{scopes: scopes}} = resolution, _) when is_list(scopes) do
    resolution
  end

  def call(resolution, _) do
    put_error_result(
      resolution,
      :scopes_not_found,
      "Could not find scopes associated with this api access token"
    )
  end
end
