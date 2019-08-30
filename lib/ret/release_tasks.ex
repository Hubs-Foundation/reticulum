defmodule Ret.ReleaseTasks do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:ret)

    Ret.Locking.exec_after_session_lock("ret_migrations", fn ->
      Ecto.Migrator.run(Ret.Repo, migrations_path(:ret), :up, all: true)
    end)
  end

  def migrate_post_start do
    if module_config(:migrate_post_start) do
      migrate()
    end
  end

  def priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])

  defp module_config(key), do: Application.get_env(:ret, __MODULE__)[key]
end
