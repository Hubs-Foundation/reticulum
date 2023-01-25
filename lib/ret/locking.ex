defmodule Ret.Locking do
  alias Ret.Repo

  def exec_if_session_lockable(lock_name, exec) do
    session_lock_db_config = module_config(:session_lock_db)
    hostname = session_lock_db_config |> Keyword.get(:hostname)
    username = session_lock_db_config |> Keyword.get(:username)
    password = session_lock_db_config |> Keyword.get(:password)
    database = session_lock_db_config |> Keyword.get(:database)
    port = session_lock_db_config |> Keyword.get(:port)
    ssl = session_lock_db_config |> Keyword.get(:ssl)

    # Set a long queue timeout here, since we need this to work even if the database is cold and 
    # is starting up (eg AWS aurora)
    {:ok, pid} =
      Postgrex.start_link(
        hostname: hostname,
        username: username,
        password: password,
        database: database,
        ssl: ssl || false,
        port: port,
        queue_interval: 60_000,
        after_connect_timeout: 60_000,
        timeout: 300_000,
        ownership_timeout: 300_000
      )

    try do
      <<lock_key::little-signed-integer-size(64), _::binary>> =
        :crypto.hash(:sha256, lock_name |> to_string)

      case Postgrex.query!(pid, "select pg_try_advisory_lock($1)", [lock_key], timeout: 60_000) do
        %Postgrex.Result{rows: [[true]]} ->
          try do
            exec.()
          after
            Postgrex.query!(pid, "select pg_advisory_unlock($1)", [lock_key])
          end

        _ ->
          nil
      end
    after
      GenServer.stop(pid)
    end
  end

  def exec_if_lockable(lock_name, exec) do
    timeout = module_config(:lock_timeout_ms)

    Repo.checkout(
      fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "set idle_in_transaction_session_timeout = #{timeout};",
          [],
          timeout: 60_000
        )

        res =
          Repo.transaction(fn ->
            <<lock_key::little-signed-integer-size(64), _::binary>> =
              :crypto.hash(:sha256, lock_name |> to_string)

            case Ecto.Adapters.SQL.query!(Repo, "select pg_try_advisory_xact_lock($1);", [
                   lock_key
                 ]) do
              %Postgrex.Result{rows: [[true]]} ->
                exec.()

              _ ->
                nil
            end
          end)

        Ecto.Adapters.SQL.query!(Repo, "set idle_in_transaction_session_timeout = 0;", [])
        res
      end,
      []
    )
  end

  def exec_after_lock(lock_name, exec) do
    timeout = module_config(:lock_timeout_ms)

    Repo.checkout(
      fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "set idle_in_transaction_session_timeout = #{timeout};",
          [],
          timeout: 60_000
        )

        res =
          Repo.transaction(fn ->
            <<lock_key::little-signed-integer-size(64), _::binary>> =
              :crypto.hash(:sha256, lock_name |> to_string)

            Ecto.Adapters.SQL.query!(Repo, "select pg_advisory_xact_lock($1);", [lock_key])

            exec.()
          end)

        Ecto.Adapters.SQL.query!(Repo, "set idle_in_transaction_session_timeout = 0;", [])
        res
      end,
      []
    )
  end

  defp module_config(key), do: Application.get_env(:ret, __MODULE__)[key]
end
