defmodule RetWeb.Api.V1.AccountView do
  use RetWeb, :view
  alias Ret.{Account}

  def render("create.json", %{account: account}) do
    %{}
  end
end
