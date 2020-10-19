defmodule RetWeb.Middleware.PutErrorResult do
  @moduledoc "Helper for returning auth errors in a uniform way in graphql api"

  import Absinthe.Resolution, only: [put_result: 2]

  def put_error_result(resolution, :no_resource_found, _message) do
    put_result(
      resolution,
      {:error,
       [
         type: :api_access_token_invalid_or_not_found,
         message: "API access token is invalid or missing. Did you add an authorization: bearer <your_token> header?"
       ]}
    )
  end

  def put_error_result(resolution, type, message) do
    put_result(
      resolution,
      {:error, [type: type, message: message]}
    )
  end
end
