defmodule RetWeb.Api.V1.ScopesView do
  use RetWeb, :view

  def render("show.json", %{scopes: scopes}) do
    %{scopes: scopes}
  end
end
