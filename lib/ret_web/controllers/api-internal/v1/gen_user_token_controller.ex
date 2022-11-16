defmodule RetWeb.ApiInternal.V1.GenUserTokenController do
  require Logger

  use RetWeb, :controller
    
  def post(conn, %{"email" => email}) when is_binary(email) do
    IO.puts("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
    # IO.puts(inspect(conn))
    IO.puts("email: #{inspect(email)}")
    
    acct = Ret.Account.account_for_email(email) 
    IO.puts("acct: #{inspect(acct)}")
    
    token = Ret.Api.TokenUtils.gen_token_for_account(acct)    
    IO.puts("token: #{inspect(token)}")
    
    # try do
    #   acct = Ret.Account.account_for_email(email) 
    #   token = Ret.Api.TokenUtils.gen_token_for_account(acct)
    #   send_resp(conn, 200, token)
    # rescue
    #   exception ->
    #     send_resp(conn, 500, exception)
    # end
    send_resp(conn, 200, token)
  end
end
