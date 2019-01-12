# general design via https://github.com/arjan/singleton
defmodule DiscordBotManager do

  use GenServer
  require Logger

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

  def handle_cast(data, state) do
    GenServer.cast({:global, DiscordSupervisor.DiscordBot}, data)
    {:noreply, state}
  end

  # it's incredibly unclear to me what errors in the discord bot result in what control flow, but
  # empirically, if there's a problem when starting the bot, sometimes an error will fly out of
  # DiscordBotManager.start_link, and sometimes it will fly out of DiscordBot.start_link, so
  # we take care to handle both. the goal in both cases is to just give up and not be running the
  # bot, with the theory that we can restart reticulum if we want to try again.

  def start_link() do
    result = GenServer.start_link(__MODULE__, [], name: __MODULE__)
    case result do
      {:error, e} -> Logger.error "Failed to start Discord bot: #{inspect(e)}"; :ignore
      other -> other
    end
  end

  defp restart(state) do
    result = DiscordSupervisor.start_link([], [name: {:global, DiscordSupervisor}])
    pid = case result do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      {:error, {:shutdown, reason}} -> Logger.error "Failed to start Discord bot: #{inspect(reason)}"; nil
    end

    if pid != nil do
      Process.monitor(pid)
    end

    %State{state | pid: pid}
  end

end
