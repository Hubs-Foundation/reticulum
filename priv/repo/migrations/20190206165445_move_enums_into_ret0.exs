defmodule Ret.Repo.Migrations.MoveEnumsIntoRet0 do
  use Ecto.Migration

  # This migration no longer needs to be run, was a one-time thing that is not repeatable
  #
  def up do
    # execute("alter type public.scene_state set schema ret0")
    # execute("alter type public.hub_entry_mode set schema ret0")
    # execute("alter type public.owned_file_state set schema ret0")
  end

  def down do
    # execute("alter type ret0.scene_state set schema public")
    # execute("alter type ret0.hub_entry_mode set schema public")
    # execute("alter type ret0.owned_file_state set schema public")
  end
end
