# TODO: Naming: not really related to auth
defmodule RetWeb.Middleware.AuthErrorUtil do
  @moduledoc "Helper for returning auth errors in a uniform way in graphql api"

  import Absinthe.Resolution, only: [put_result: 2]

  # TODO: message is not always a string but needs to be. e.g. Authorization: bearer: foo
  def put_error_result(resolution, type, message) do
    put_result(
      resolution,
      {:error, [type: type, message: message]}
    )
  end
end
