defmodule Ret.DbWarmerJob do
  import Ecto.Query

  # Routine run to keep database up when there are any CCU.
  # For AWS aurora, database shuts down if not being used.
  def warm_db_if_has_ccu do
    if RetWeb.Presence.has_present_members?() do
      # Ping DB to keep up
      Ret.Repo.all(from h in Ret.Hub, limit: 0)
    end
  end
end
