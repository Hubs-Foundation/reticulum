defmodule Ret.ReleaseTasks do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:ret)

    Ret.Locking.exec_if_session_lockable("ret_migration", fn ->
      Ecto.Adapters.SQL.query!(Ret.Repo, "CREATE SCHEMA IF NOT EXISTS ret0")

      Ecto.Migrator.run(Ret.Repo, migrations_path(:ret), :up, all: true, prefix: "ret0")
    end)
  end

  def priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])
end
