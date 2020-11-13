defmodule Mix.Tasks.GenerateApiToken do
  @moduledoc "Generates an Api Token for the given account email"

  use Mix.Task

  alias Ret.{Account}
  alias Ret.Api.TokenUtils

  @impl Mix.Task
  def run(_) do
    user_or_app =
      "Generate user token or app token? [user or app]"
      |> Mix.shell().prompt()
      |> String.trim()

    case user_or_app do
      "user" ->
        gen_user_token()

      "app" ->
        gen_app_token()

      _ ->
        Mix.shell().error("Input not recognized. Type \"user\" or \"app\".")
        run([])
    end
  end

  defp gen_user_token() do
    email =
      "Enter email address of the user whose account will be associated in this token: [foo@bar.com]\n"
      |> Mix.shell().prompt()
      |> String.trim()

    Mix.Task.run("app.start")

    case Account.account_for_email(email) do
      nil ->
        Mix.shell().error("Could not find account for the given email address: #{email}")

      account ->
        IO.puts("Account found:")

        account
        |> Inspect.Algebra.to_doc(%Inspect.Opts{})
        |> Inspect.Algebra.format(80)
        |> IO.puts()

        if Mix.shell().yes?("Generate token for this account [#{email}]?") do
          gen_token_for_account(account)
        end
    end
  end

  defp gen_app_token() do
    if Mix.shell().yes?("Are you sure you want to generate an app token?") do
      Mix.Task.run("app.start")

      case TokenUtils.gen_app_token() do
        {:ok, token, _claims} ->
          Mix.shell().info("Successfully generated token:\n#{token}")

        {:error, reason} ->
          Mix.shell().error("Error: #{reason}")
      end
    end
  end

  defp gen_token_for_account(account) do
    case TokenUtils.gen_token_for_account(account) do
      {:ok, token, _claims} ->
        Mix.shell().info("Successfully generated token:\n#{token}")

      {:error, reason} ->
        Mix.shell().error("Error: #{reason}")
    end
  end
end
