defmodule Ret.Locking do
  alias Ret.Repo

  def exec_after_session_lock(lock_name, exec) do
    Repo.checkout(
      fn ->
        <<lock_key::little-signed-integer-size(64), _::binary>> = :crypto.hash(:sha256, lock_name |> to_string)
        %Postgrex.Result{rows: [[:void]]} = Ecto.Adapters.SQL.query!(Repo, "select pg_advisory_lock($1);", [lock_key])

        try do
          exec.()
        after
          Ecto.Adapters.SQL.query!(Repo, "select pg_advisory_unlock($1);", [lock_key])
        end
      end,
      []
    )
  end

  def exec_if_lockable(lock_name, exec) do
    timeout = module_config(:lock_timeout_ms)

    Repo.checkout(
      fn ->
        Ecto.Adapters.SQL.query!(Repo, "set idle_in_transaction_session_timeout = #{timeout};", [])

        Repo.transaction(fn ->
          <<lock_key::little-signed-integer-size(64), _::binary>> = :crypto.hash(:sha256, lock_name |> to_string)

          case Ecto.Adapters.SQL.query!(Repo, "select pg_try_advisory_xact_lock($1);", [lock_key]) do
            %Postgrex.Result{rows: [[true]]} ->
              exec.()

            _ ->
              nil
          end
        end)

        Ecto.Adapters.SQL.query!(Repo, "set idle_in_transaction_session_timeout = 0;", [])
      end,
      []
    )
  end

  def exec_after_lock(lock_name, exec) do
    timeout = module_config(:lock_timeout_ms)

    Repo.checkout(
      fn ->
        Ecto.Adapters.SQL.query!(Repo, "set idle_in_transaction_session_timeout = #{timeout};", [])

        Repo.transaction(fn ->
          <<lock_key::little-signed-integer-size(64), _::binary>> = :crypto.hash(:sha256, lock_name |> to_string)

          Ecto.Adapters.SQL.query!(Repo, "select pg_advisory_xact_lock($1);", [lock_key])

          exec.()
        end)

        Ecto.Adapters.SQL.query!(Repo, "set idle_in_transaction_session_timeout = 0;", [])
      end,
      []
    )
  end

  defp module_config(key), do: Application.get_env(:ret, __MODULE__)[key]
end
