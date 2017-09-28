defmodule Ret.ReleaseTasks do
  @start_apps [:crypto, :ssl, :postgrex, :ecto]

  def migrate do
    start
    Ecto.Migrator.run(Ret.Repo, migrations_path(:ret), :up, all: true)
    :init.stop()
  end

  def createdb do
    start
    Ret.Repo.__adapter__.storage_up(Ret.Repo.config)
    :init.stop()
  end

  defp start do
    :ok = Application.load(:ret)
    Enum.each(@start_apps, &Application.ensure_all_started/1)
    Ret.Repo.start_link(pool_size: 1)
  end

  def priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])
end
