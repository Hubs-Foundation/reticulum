defmodule FlatBuffersSerializerTest do
  use ExUnit.Case

  alias RetWeb.Transports.FlatBuffersSerializer
  alias Phoenix.Socket.{Reply, Message, Broadcast}

  setup do
    {:ok, message} = File.read("test/ret_web/transports/message.json")

    {:ok, presence_diff} = File.read("test/ret_web/transports/presence_diff.json")

    {:ok, %{message: message, presence_diff: presence_diff}}
  end

  test "test load_schema" do 
    port = FlatbufferPort.open_port()
    assert {:ok, "load schema ok"} == FlatBuffersSerializer.load_schema(port)
    Port.close(port)
  end

  test "test pack_data", %{message: message} do 
    {:ok, packed} = FlatBuffersSerializer.pack_data(message)

    assert Poison.decode!(message, as: %Message{}) == FlatBuffersSerializer.decode!(packed)
  end

  test "test presence_diff", %{presence_diff: presence_diff} do
    broadcast = %Broadcast{
      topic: "room:lobby",
      event: "presence_diff", 
      payload: %{
        :joins => %{
          "klee@mozilla.com" => %{
            metas: [%{online_at: 1507939718, phx_ref: "wAM7sYbo0Nw="}]
          }
        }, 
        leaves: %{}
      }
    }

    {:socket_push, :binary, data} = FlatBuffersSerializer.fastlane!(broadcast)

    {:ok, packed} = FlatBuffersSerializer.pack_data(presence_diff)
   
    # TODO: somehow 'data' and 'packed' differ by 4 bytes, and im not sure why
    assert byte_size(packed) == byte_size(data)
    assert packed == data

    # generated with flatc.exe --binary chat.fbs presence_diff.json
    {:ok, packed2} = File.read("test/ret_web/transports/presence_diff.bin")

    assert byte_size(packed) == byte_size(packed2)
    assert packed == packed2
  end

end
