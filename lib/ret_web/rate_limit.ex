defmodule RetWeb.Plugs.RateLimit do
  use PlugAttack

  throttle? =
    :ret
    |> Application.compile_env!(__MODULE__)
    |> Keyword.fetch!(:throttle?)

  if throttle? do
    rule "throttle by ip to 1 tps", conn do
      throttle(
        conn.remote_ip,
        period: 1000,
        limit: 1,
        storage: {PlugAttack.Storage.Ets, RetWeb.RateLimit.Storage}
      )
    end
  end
end
