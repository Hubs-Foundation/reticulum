defmodule Ret.BasicAuth do
  use RetWeb, :controller

  @moduledoc """
  Plug for adding basic authentication.
  """

  defmodule Callback do
    @moduledoc false
    defstruct callback: nil, realm: nil
  end

  def init([use_config: config_options]) do
    BasicAuth.Configured.init(config_options)
  end

  def init(options) when is_list(options) do
    BasicAuth.WithCallback.init(options)
  end

  def init(_) do
    raise ArgumentError, """

    Usage of BasicAuth using application config:
    plug BasicAuth, use_config: {:your_app, :your_config}

    -OR-
    Using custom authentication function:
    plug BasicAuth, callback: &MyCustom.function/3

    Where :callback takes either
    * a conn, username and password and returns a conn.
    * a conn and a key and returns a conn
    """
  end

  def call(conn, options) do
    case current_path(conn, %{}) do
      "/client/"<>_path ->
        header_content = Plug.Conn.get_req_header(conn, "authorization")
        respond(conn, header_content, options)
      _ -> conn
    end
  end

  defp respond(conn, header_content, config_options = %BasicAuth.Configured{}) do
    BasicAuth.Configured.respond(conn, header_content, config_options)
  end
  defp respond(conn, header_content, config_options = %BasicAuth.WithCallback{}) do
    BasicAuth.WithCallback.respond(conn, header_content, config_options)
  end
end
