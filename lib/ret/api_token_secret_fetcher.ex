# TODO: How to set configuration for prod?
defmodule Ret.ApiTokenSecretFetcher do
  @moduledoc false
  def fetch_signing_secret(_mod, _opts) do
    {:ok, Application.get_env(:ret, Ret.ApiToken)[:secret_key] |> JOSE.JWK.from_oct()}
  end

  def fetch_verifying_secret(_mod, _token_headers, _opts) do
    {:ok, Application.get_env(:ret, Ret.ApiToken)[:secret_key] |> JOSE.JWK.from_oct()}
  end
end
