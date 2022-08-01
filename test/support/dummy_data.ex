defmodule Ret.DummyData do
  @spec account_prefix :: String.t()
  def account_prefix,
    do: "test-user-account-prefix-account-user"

  @spec domain_url :: String.t()
  def domain_url,
    do: "http://example.com"

  @spec project_name :: String.t()
  def project_name,
    do: "some project name"

  @spec scene_name :: String.t()
  def scene_name,
    do: "some scene name"
end
