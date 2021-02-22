defmodule Ret.Api.Dataloader do
  @moduledoc "Configuration for dataloader"

  import Ecto.Query
  alias Ret.{Repo, Scene, SceneListing}

  def source(), do: Dataloader.Ecto.new(Repo, query: &query/2)
  # Guard against loading removed scenes or delisted scene listings
  def query(Scene, _), do: from(s in Scene, where: s.state != ^:removed)
  def query(SceneListing, _), do: from(sl in SceneListing, where: sl.state != ^:delisted)
end
