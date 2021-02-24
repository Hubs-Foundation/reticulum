# TODO: Add metrics from various telemetry-enabled libraries (e.g. absinthe)
# TODO: Add storage and enable history https://hexdocs.pm/phoenix_live_dashboard/metrics_history.html
defmodule RetWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Time Metrics
      summary("ret.repo.query.total_time", unit: {:native, :millisecond}),
      summary("ret.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("ret.repo.query.query_time", unit: {:native, :millisecond}),
      summary("ret.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("ret.repo.query.idle_time", unit: {:native, :millisecond}),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Absinthe
      # summary("absinthe.execute.operation.start"),
      # summary("absinthe.execute.operation.stop"),
      # summary("absinthe.subscription.publish.start"),
      # summary("absinthe.subscription.publish.stop"),
      # summary("absinthe.resolve.field.start"),
      # summary("absinthe.resolve.field.stop"),
      # summary("absinthe.middleware.batch.start"),
      # summary("absinthe.middleware.batch.stop"),
      # TODO: Learn how these metrics work
      summary("absinthe.execute.operation.stop.duration"),
      summary("absinthe.subscription.publish.stop.duration"),
      summary("absinthe.resolve.field.stop.duration"),
      summary("absinthe.middleware.batch.stop.duration")
    ]
  end

  defp periodic_measurements do
    []
  end
end
