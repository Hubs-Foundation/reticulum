defmodule Ret.ReleaseTasks do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:ret)

    Ret.Locking.exec_after_session_lock("ret_migration", fn ->
      Ecto.Migrator.run(Ret.Repo, migrations_path(:ret), :up, all: true)
    end)
  end

  def priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])
end
