defmodule Ret.ReleaseTasks do
  @start_apps [:crypto, :ssl, :postgrex, :ecto]

  def migrate do
    {:ok, _} = Application.ensure_all_started(:ret)
    Ecto.Migrator.run(Ret.Repo, migrations_path(:ret), :up, all: true)
  end

  def priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])
end
