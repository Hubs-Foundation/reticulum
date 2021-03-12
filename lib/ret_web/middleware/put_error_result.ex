defmodule RetWeb.Middleware.PutErrorResult do
  @moduledoc "Helper for returning auth errors in a uniform way in graphql api"

  import Absinthe.Resolution, only: [put_result: 2]

  def put_error_result(resolution, type, message) do
    put_result(
      resolution,
      {:error, [type: type, message: message]}
    )
  end
end
