defmodule RetWeb.Api.V1.AccountView do
  use RetWeb, :view

  def render("create.json", %{account: account, email: email}) do
    %{
      id: "#{account.account_id}",
      email: email
    }
  end
end
