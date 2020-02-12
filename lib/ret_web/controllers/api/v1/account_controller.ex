defmodule RetWeb.Api.V1.AccountController do
  use RetWeb, :controller
  import RetWeb.ApiHelpers

  alias Ret.{Account}
  alias RetWeb.Api.V1.{AccountView}

  # TODO move to a file
  @record_schema %{
                   "type" => "object",
                   "properties" => %{
                     "email" => %{
                       "type" => "string",
                       "format" => "email"
                     },
                     "name" => %{
                       "type" => "string",
                       "minLength" => 2,
                       "maxLength" => 64
                     }
                   },
                   "required" => ["email"]
                 }
                 |> ExJsonSchema.Schema.resolve()

  def create(conn, params) do
    exec_api_create(conn, params, @record_schema, &process_account_create_record/2)
  end

  defp process_account_create_record(%{"email" => email} = params, source) do
    if Account.exists_for_email?(email) do
      {:error, [{:RECORD_EXISTS, "Account with email already exists.", source}]}
    else
      account = Account.find_or_create_account_for_email(email)

      account =
        if params["name"] do
          account |> Account.set_identity!(params["name"])
        else
          account
        end

      {:ok, {200, Phoenix.View.render(AccountView, "create.json", account: account, email: email)}}
    end
  end
end
