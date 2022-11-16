defmodule RetWeb.ApiInternal.V1.GenUserTokenController do
  require Logger

  use RetWeb, :controller
  
  alias Ret.{Account}
  
  @starts_with_https ~r/^https:\/\//
  def update(conn, %{"old_email" => old_email, "new_email" => new_email}) do    
    try do
      acct = Account.account_for_email(email) 
      token = TokenUtils.gen_token_for_account(acct)
      send_resp(conn, 200, token)
    rescue
      exception ->
        send_resp(conn, 500, exception)
    end
  end
end
