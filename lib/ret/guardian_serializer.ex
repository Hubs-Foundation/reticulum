defmodule Ret.GuardianSerializer do
  alias Ret.User
  alias Ret.Repo

  @behaviour Guardian.Serializer

  def for_token(user = %User{}), do: { :ok, "User:#{user.user_id}" }
  def for_token(_), do: { :error, "Unknown resource" }

  def from_token("User:" <> id), do: { :ok, Repo.get(User, id) }
  def from_token(_), do: { :error, "Bad token" }
end
