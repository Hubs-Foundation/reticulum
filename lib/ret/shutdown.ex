defmodule Ret.Shutdown do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, {}}
  end

  def handle_info(:ping, state) do
    {:noreply, state}
  end

  def terminate(_, _) do
  end
end
