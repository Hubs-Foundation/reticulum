defmodule Ret.Meta do
  # Evaluate at build time
  @version Mix.Project.config()[:version]

  def get_meta do
    %{
      version: @version,
      phx_host: :inet.gethostname() |> elem(1) |> to_string,
      pool: Application.get_env(:ret, Ret)[:pool]
    }
  end
end
