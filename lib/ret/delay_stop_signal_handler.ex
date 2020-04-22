# This gen_event handler allows a temporary delay of handling
# SIGTERM to shut down the application.
#
# Calling delay_stop will cease handling SIGTERM, then calling
# allow_stop will resume it. If SIGTERM was seen in the interim,
# the application will then stop.
defmodule Ret.DelayStopSignalHandler do
  @moduledoc false

  def init(_), do: {:ok, %{saw_sigterm: false}}

  def delay_stop do
    :ok =
      :gen_event.swap_sup_handler(
        :erl_signal_server,
        {:erl_signal_handler, []},
        {Ret.DelayStopSignalHandler, []}
      )
  end

  def allow_stop do
    :gen_event.call(:erl_signal_server, Ret.DelayStopSignalHandler, {:allow_stop, self()})

    :ok =
      :gen_event.swap_sup_handler(
        :erl_signal_server,
        {Ret.DelayStopSignalHandler, []},
        {:erl_signal_handler, []}
      )
  end

  def handle_call({:allow_stop, _pid}, %{saw_sigterm: true} = state) do
    :init.stop()
    {:ok, :ok, state}
  end

  def handle_call({:allow_stop, _pid}, state), do: {:ok, :ok, state}
  def handle_event(:sigterm, state), do: {:ok, state |> Map.put(:saw_sigterm, true)}
end
