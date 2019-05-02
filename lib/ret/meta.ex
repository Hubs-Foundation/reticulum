defmodule Ret.Meta do
  # Evaluate at build time
  @version Mix.Project.config()[:version]

  def get_meta do
    %{
      version: @version,
      phx_host: :net_adm.localhost() |> :net_adm.dns_hostname() |> elem(1) |> to_string,
      phx_port: Application.get_env(:ret, RetWeb.Endpoint)[:https][:port] |> to_string,
      pool: Application.get_env(:ret, Ret)[:pool]
    }
  end
end
