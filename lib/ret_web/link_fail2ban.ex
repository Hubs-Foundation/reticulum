defmodule RetWeb.Plugs.LinkFail2Ban do
  use PlugAttack

  if Mix.env() != :test do
    rule "Ban IP for 2 hours if we see more than 1 entry code requests per second", conn do
      hub_sid_or_entry_code = conn.params["path"] |> Enum.at(0)

      # Hub SIDs are 7 character alpha-numerics. Entry codes are 6 digits.
      is_entry_code = String.match?(hub_sid_or_entry_code, ~r/^\d{6}$/)

      if is_entry_code do
        fail2ban_entry_code(conn)
      else
        # We never want to ban hub sids.
        {:allow, nil}
      end
    end
  end

  defp fail2ban_entry_code(conn) do
    forwarded_ip = conn.req_headers |> Ret.HttpUtils.get_forwarded_ip()
    remote_ip = forwarded_ip || conn.remote_ip

    case PlugAttack.Rule.fail2ban(
           remote_ip,
           # We need to use a limit of 2 over a period of 2 seconds here,
           # since PlugAttack's fail2ban algorithm behaves incorrectly with a limit of 1
           limit: 2,
           period: 2000,
           ban_for: 1000 * 60 * 60 * 2,
           storage: {PlugAttack.Storage.Ets, RetWeb.LinkFail2Ban.Storage}
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
