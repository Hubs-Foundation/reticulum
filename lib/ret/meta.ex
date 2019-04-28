defmodule Ret.Meta do
  def get_meta do
    %{
      version: :application.get_key(:ret, :vsn) |> elem(1) |> to_string,
      phx_host: :inet.gethostname() |> elem(1) |> to_string,
      pool: Application.get_env(:ret, Ret)[:pool]
    }
  end
end
