# This repo is intended to be the same as Ret.Repo, except statements/transactions
# execute in a session context (vs a transaction context) when running in an environment
# with pgbouncer.
defmodule Ret.SessionLockRepo do
  use Ecto.Repo, otp_app: :ret, adapter: Ecto.Adapters.Postgres

  def init(_, opts) do
    {:ok, opts}
  end

  def set_search_path(conn, path) do
    {:ok, _result} = Postgrex.query(conn, "set search_path=#{path}", [])
  end
end
