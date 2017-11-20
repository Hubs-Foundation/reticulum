defmodule RetWeb.Transports.FlatBuffersSerializer do
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.{Reply, Message, Broadcast}

  def fastlane!(%Broadcast{event: "presence_diff"} = broadcast) do
    payload = %{
      joins: format_presence(broadcast.payload.joins), 
      leaves: format_presence(broadcast.payload.leaves)
    }

    broadcast
    |> Map.put(:payload, payload)
    |> encode_and_pack!
  end

  def fastlane!(%Broadcast{} = broadcast) do
    encode_and_pack!(broadcast)
  end

  def encode!(%Reply{} = reply) do
    reply
    |> Map.put(:event, "phx_reply")
    |> Map.put(:payload, %{status: reply.status, response: reply.payload})
    |> encode_and_pack!
  end

  def encode!(%Message{event: "presence_state"} = msg) do
    %Message{msg | payload: %{state: format_presence(msg.payload)}} 
    |> encode_and_pack!
  end

  def encode!(%Message{} = msg) do
    encode_and_pack!(msg)
  end

  def decode!(raw_message, _opts \\ []) do
    port = FlatbufferPort.open_port()
    load_schema(port)

    FlatbufferPort.fb_to_json(port, raw_message)
    case collect_response() do
      {:response, "error: " <> error} ->
        Port.close(port) 
        IO.puts "decode! error: " <> error
      {:response, json} ->
        Port.close(port)
        json
        |> Poison.decode!(as: %Message{})
    end
  end

  def pack_data(json) do
    port = FlatbufferPort.open_port()

    load_schema(port)

    FlatbufferPort.json_to_fb(port, json)
    case collect_response() do
      {:response, "error: " <> error} ->
        Port.close(port)
        {:error, "pack_data error: " <> error}
      {:response, response} ->
        Port.close(port)
        {:ok, response}
    end
  end

  def load_schema(port) do
    {:ok, schema} = File.read("lib/ret_web/transports/chat.fbs")

    FlatbufferPort.load_schema(port, schema)
    case collect_response() do
      {:response, "error: " <> error} ->
        throw "load_schema error: " <> error
      {:response, "ok"} ->
        {:ok, "load schema ok"}
    end
  end

  defp encode_and_pack!(msg) do
    {:ok, data} = pack_data(Poison.encode!(msg))
    {:socket_push, :binary, data}
  end

  defp format_presence(payload) do
    for {key, %{metas: metas}} <- payload, into: [] do
      %{user: key, metas: metas}
    end
  end

  defp collect_response() do
    receive do
      {_port, {:data, data}}  ->  {:response, data}
    after
      3000 -> :timeout
    end
  end

end
