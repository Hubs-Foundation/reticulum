ExUnit.configure(Application.get_env(:ret, :ex_unit_configuration, []))
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Ret.Repo, :manual)
