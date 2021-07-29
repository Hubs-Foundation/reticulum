defmodule RetWeb.Plugs.Fail2Ban do
  use PlugAttack

  if Mix.env() != :test do
    rule "throttle and ban IP for 2 hours if we see more than 1 request per second", conn do
      case fail2ban(
             conn.remote_ip,
             # We need to use a limit of 2 over a period of 2 seconds here,
             # since PlugAttack's fail2ban algorithm behaves incorrectly with a limit of 1
             limit: 2,
             period: 2000,
             ban_for: 1000 * 60 * 60 * 2,
             storage: {PlugAttack.Storage.Ets, RetWeb.Fail2Ban.Storage}
           ) do
        {:block, {:fail2ban, :counting, _}} ->
          {:allow, nil}

        {:block, {:fail2ban, :banned, _}} ->
          {:block, nil}

        _ ->
          {:block, nil}
      end
    end
  end
end
