defmodule RetWeb.ApiInternal.V1.LoadAssetController do
  require Logger

  use RetWeb, :controller
    
  def post(conn, %{"admin-email" => email, "uri"=> uri_string, "type" => type}) 
    when is_binary(email) and is_binary(uri_string) and is_binary(type) do
    IO.puts("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
    # IO.puts(inspect(conn))
    IO.puts("email: #{email}")
    
    uri = URI.parse(uri_string)
    IO.puts("uri: #{inspect(uri)}")

    account = Ret.Account.account_for_email(email) 
    IO.puts("account: #{inspect(account)}")
    
    # IO.puts("type: #{type}")

    # case type do
    #   "avatar" ->
    #     Ret.Avatar.import_from_url!(uri, account)
    #   "scene" ->
    #     Ret.Scene.import_from_url!(uri, account)
    #   _ ->
    #     send_resp(conn, 400, "unknown type: #{type}")
    # end
        
    token =
      %{}
      |> Map.put(:account_id, account.account_id)
      |> Ret.PermsToken.token_for_perms()
      
    IO.puts("~~~~~~token: #{token}~~~~~~~~~~~~~~~~~~~~~~~~")
      
    # token = Ret.Api.TokenUtils.gen_token_for_account(acct)    
    # IO.puts("token: #{inspect(token)}")
    
    # try do
    #   acct = Ret.Account.account_for_email(email) 
    #   token = Ret.Api.TokenUtils.gen_token_for_account(acct)
    #   send_resp(conn, 200, token)
    # rescue
    #   exception ->
    #     send_resp(conn, 500, exception)
    # end
    # send_resp(conn, 200, token)
  end
end
