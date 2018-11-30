# general design via https://github.com/arjan/singleton
defmodule DiscordBotManager do

  use GenServer

  defmodule State do
    defstruct pid: nil
  end

  def init(_args) do
    {:ok, restart(%State{})}
  end

  # managed process exited normally
  def handle_info({:DOWN, _, :process, pid, :normal}, state = %State{pid: pid}) do
    {:stop, :normal, state}
  end

  # managed process exited with an error
  def handle_info({:DOWN, _, :process, pid, _reason}, state = %State{pid: pid}) do
    {:noreply, restart(state)}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  defp restart(state) do
    result = DiscordBot.start_link([], [name: {:global, DiscordBot}])
    pid = case result do
            {:ok, pid} -> pid
            {:error, {:already_started, pid}} -> pid
          end
    Process.monitor(pid)
    %State{state | pid: pid}
  end

end
