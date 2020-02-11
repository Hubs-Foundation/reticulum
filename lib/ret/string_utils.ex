defmodule Ret.StringUtils do
  def valid_email?(email), do: Regex.match?(~r/^[A-Za-z0-9\._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}$/, email)
end
