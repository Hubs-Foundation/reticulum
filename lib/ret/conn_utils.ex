defmodule Ret.ConnUtils do
  def matches_host(_conn, nil), do: false
  def matches_host(_conn, ""), do: false
  def matches_host(conn, host), do: Regex.match?(~r/\A#{conn.host}\z/i, host)
end
