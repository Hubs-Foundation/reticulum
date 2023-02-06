defmodule Ret.RoomAssignerMonitor do
  use GenServer

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    {:ok, ensure_assigner_process()}
  end

  def handle_info({:DOWN, _, :process, _pid, :normal}, assigner_pid) do
    # Normal shutdown, shut down monitor
    {:stop, :normal, assigner_pid}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, _assigner_pid) do
    # Crash/disconnect, restart it
    {:noreply, ensure_assigner_process()}
  end

  defp ensure_assigner_process do
    pid =
      case GenServer.start_link(Ret.RoomAssigner, [], name: {:global, Ret.RoomAssigner}) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    Process.monitor(pid)
    pid
  end
end
