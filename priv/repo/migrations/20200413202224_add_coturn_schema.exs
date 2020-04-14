defmodule Ret.Repo.Migrations.AddCoturnSchema do
  use Ecto.Migration

  def up do
    execute(
      "create table coturn.turn_secret (realm varchar(127), value varchar(256), inserted_at timestamp, updated_at timestamp)"
    )

    execute(
      "create table coturn.allowed_peer_ip (realm varchar(127), ip_range varchar(256), inserted_at timestamp, updated_at timestamp)"
    )

    execute(
      "create table coturn.denied_peer_ip (realm varchar(127), ip_range varchar(256), inserted_at timestamp, updated_at timestamp)"
    )
  end

  def down do
    execute("drop table coturn.turn_secret")
    execute("drop table coturn.allowed_peer_ip")
    execute("drop table coturn.denied_peer_ip")
  end
end
