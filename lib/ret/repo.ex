defmodule Ret.Repo do
  use Ecto.Repo, otp_app: :ret

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  def set_search_path(conn, path) do
    { :ok, _result } = Postgrex.query(conn, "set search_path=#{path}", [])
  end
end
