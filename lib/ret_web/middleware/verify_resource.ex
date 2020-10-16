# TODO: This is probably unnecessary
defmodule RetWeb.Middleware.VerifyResource do
  @moduledoc false

  @behaviour Absinthe.Middleware

  import RetWeb.Middleware.PutErrorResult, only: [put_error_result: 3]

  def call(%{state: :resolved} = resolution, _) do
    resolution
  end

  def call(%{context: %{resource: :reticulum_app_token}} = resolution, _) do
    resolution
  end

  def call(%{context: %{resource: %Ret.Account{}}} = resolution, _) do
    resolution
  end

  def call(resolution, _) do
    put_error_result(
      resolution,
      :resource_not_found,
      "Could not find resource associated with this api access token"
    )
  end
end
