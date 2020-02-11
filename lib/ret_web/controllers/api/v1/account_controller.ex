defmodule RetWeb.Api.V1.AccountController do
  use RetWeb, :controller

  alias Ret.{Account, Repo}

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
    exec_create(conn, params, &process_account_create_record/3)
  end

  defp process_account_create_record(conn, %{"email" => email}, source) do
    {:ok, {200, "OK"}}
    # case result do
    #  :ok -> render(conn, "create.json", hub: hub)
    #  :error -> conn |> send_resp(422, "invalid hub")
    # end
  end

  # Utility functions
  defp exec_create(conn, %{"data" => data}, handler), do: process_create_records(conn, data, handler)

  defp exec_create(conn, _invalid_params, _handler) do
    conn |> send_error_resp([{:MALFORMED_REQUEST, "Missing 'data' property in request.", nil}])
  end

  defp process_create_records(conn, record, handler) when is_map(record) do
    case ExJsonSchema.Validator.validate(@record_schema, record, error_formatter: Ret.JsonSchemaApiErrorFormatter) do
      :ok ->
        case handler.(conn, record, "data") do
          {:ok, {status, body}} ->
            conn |> send_resp(status, body)

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

  defp process_create_records(conn, _record, handler) do
    conn
    |> send_error_resp([{:MALFORMED_RECORD, "Malformed record in 'data' property.", "data"}])
  end

  defp send_error_resp(conn, errors) do
    conn
    |> send_resp(
      400,
      %{errors: Enum.map(errors, fn {code, detail, source} -> %{code: code, detail: detail, source: source} end)}
      |> Poison.encode!()
    )
  end
end
