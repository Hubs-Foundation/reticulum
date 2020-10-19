defmodule RetWeb.Middleware.PutErrorResult do
  @moduledoc "Helper for returning auth errors in a uniform way in graphql api"

  import Absinthe.Resolution, only: [put_result: 2]

  def put_error_result(resolution, :no_resource_found, _message) do
    put_result(
      resolution,
      {:error,
       [
         type: :missing_or_invalid_credentials,
         message: "API access token is missing or invalid. Did you add an authorization: bearer <your_token> header?"
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
