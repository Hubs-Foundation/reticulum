defmodule RetWeb.Resolvers.ResolverError do
  @moduledoc false
  def resolver_error(type, reason) do
    {:error, [type: type, message: reason]}
  end
end
