defmodule RetWeb.Api.V1.ScopesView do
  use RetWeb, :view

  # alias Ret.Api.Scopes

  def render("show.json", %{scopes: scopes}) do
    IO.puts("inside show.json")
    IO.inspect(scopes)
    IO.inspect(%{scopes: scopes})
    %{scopes: scopes}
  end
end
