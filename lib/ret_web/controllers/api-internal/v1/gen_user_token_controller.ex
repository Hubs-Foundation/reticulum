defmodule RetWeb.ApiInternal.V1.GenUserTokenController do
  require Logger

  use RetWeb, :controller
    
  def post(conn, %{"email" => email}) do    
    try do
      acct = Ret.Account.account_for_email(email) 
      token = Ret.Api.TokenUtils.gen_token_for_account(acct)
      send_resp(conn, 200, token)
    rescue
      exception ->
        send_resp(conn, 500, exception)
    end
  end
end
