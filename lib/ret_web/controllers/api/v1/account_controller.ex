defmodule RetWeb.Api.V1.AccountController do
  use RetWeb, :controller

  alias Ret.{Account}
  alias RetWeb.Api.V1.{AccountView}

  # TODO move to a file
  @record_schema %{
                   "type" => "object",
                   "properties" => %{
                     "email" => %{
                       "type" => "string",
                       "format" => "email"
                     }
                   },
                   "required" => ["email"]
                 }
                 |> ExJsonSchema.Schema.resolve()

  def create(conn, params) do
    exec_create(conn, params, &process_account_create_record/2)
  end

  defp process_account_create_record(%{"email" => email}, source) do
    if Account.exists_for_email?(email) do
      {:error, [{:RECORD_EXISTS, "Account with email already exists.", source}]}
    else
      account = Account.find_or_create_account_for_email(email)

      {:ok, {200, Phoenix.View.render(AccountView, "create.json", account: account, email: email)}}
    end
  end

  # Utility functions
  defp exec_create(conn, %{"data" => data}, handler), do: process_create_records(conn, data, handler)

  defp exec_create(conn, _invalid_params, _handler) do
    conn |> send_error_resp([{:MALFORMED_REQUEST, "Missing 'data' property in request.", nil}])
  end

  defp process_create_records(conn, record, handler) when is_map(record) do
    case ExJsonSchema.Validator.validate(@record_schema, record, error_formatter: Ret.JsonSchemaApiErrorFormatter) do
      :ok ->
        case handler.(record, "data") do
          {:ok, {status, result}} ->
            conn |> send_resp(status, %{"data" => result} |> Poison.encode!())

          {:error, errors} ->
            conn |> send_error_resp(errors)
        end

      {:error, errors} ->
        conn
        |> send_error_resp(
          Enum.map(errors, fn {code, detail, source} -> {code, detail, source |> String.replace(~r/^#/, "data")} end)
        )
    end
  end

  defp process_create_records(conn, records, handler) when is_list(records) do
    results =
      records
      |> Enum.with_index()
      |> Enum.map(fn {record, index} ->
        case ExJsonSchema.Validator.validate(@record_schema, record, error_formatter: Ret.JsonSchemaApiErrorFormatter) do
          :ok ->
            case handler.(record, "data[#{index}]") do
              {:ok, {status, result}} ->
                %{status: status, body: %{"data" => result}}

              {:error, errors} ->
                %{status: 400, body: to_error_multi_request_response(errors)}
            end

          {:error, errors} ->
            %{
              status: 400,
              body:
                to_error_multi_request_response(
                  Enum.map(errors, fn {code, detail, source} ->
                    {code, detail, source |> String.replace(~r/^#/, "data[#{index}]")}
                  end)
                )
            }
        end
      end)

    conn |> send_resp(207, results |> Poison.encode!())
  end

  defp process_create_records(conn, _record, _handler) do
    conn
    |> send_error_resp([{:MALFORMED_RECORD, "Malformed record in 'data' property.", "data"}])
  end

  defp send_error_resp(conn, [{:RECORD_EXISTS, _detail, _source}] = errors), do: conn |> send_error_resp(409, errors)
  defp send_error_resp(conn, errors), do: send_error_resp(conn, 400, errors)

  defp send_error_resp(conn, status, errors) do
    conn
    |> send_resp(
      status,
      %{errors: Enum.map(errors, fn {code, detail, source} -> %{code: code, detail: detail, source: source} end)}
      |> Poison.encode!()
    )
  end

  defp to_error_multi_request_response(errors) do
    %{errors: Enum.map(errors, fn {code, detail, source} -> %{code: code, detail: detail, source: source} end)}
  end
end
