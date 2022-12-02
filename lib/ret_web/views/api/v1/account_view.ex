defmodule RetWeb.Api.V1.AccountView do
  use RetWeb, :view

  alias Ret.{Account, Identity}

  def render("create.json", %{
        account: %Account{identity: %Identity{name: name}} = account,
        email: email
      }) do
    %{
      id: "#{account.account_id}",
      login: %{email: email},
      identity: %{name: name}
    }
  end

  def render("create.json", %{account: account, email: email}) do
    %{
      id: "#{account.account_id}",
      login: %{email: email}
    }
  end

  def render("show.json", %{account: %Account{identity: %Identity{name: name}} = account}) do
    %{
      id: "#{account.account_id}",
      identity: %{name: name}
    }
  end

  def render("show.json", %{account: account}) do
    %{
      id: "#{account.account_id}"
    }
  end
end
