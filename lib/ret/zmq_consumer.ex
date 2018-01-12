require IEx

defmodule ZMQConsumer do
  defmodule State do
    defstruct req_socket: nil, pending_message: << >>
  end

  def connect do
    { :ok, s } = :chumak.socket(:req, 'Ret #{:os.system_time(:milli_seconds)}')
    { :ok, _conn } = :chumak.connect(s, :tcp, '127.0.0.1', 5555)

    { :ok, %State{ req_socket: s } }
  end

  def next(%State{req_socket: req_socket, pending_message: << >>} = state) do
    :ok = :chumak.send(req_socket, << 0 >>)
    { :ok, << len_binary :: binary-size(8), rest :: binary >> } = :chumak.recv(req_socket)

    # Get length of first message payload, and split
    len = len_binary |> :binary.decode_unsigned(:little)
    << primary :: binary-size(len) , secondary :: binary >> = rest

    { primary, Map.replace(state, :pending_message, secondary) }
  end

  def next(%State{req_socket: _, pending_message: pending_message} = state) do
    { pending_message, Map.replace(state, :pending_message, << >>) }
  end
end
