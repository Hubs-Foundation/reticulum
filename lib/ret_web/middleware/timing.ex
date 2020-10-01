defmodule RetWeb.Middleware.TimingUtil do
  @moduledoc false
  def add_timing_info(%Absinthe.Resolution{private: private} = resolution, identifier, key, value) do
    timing = Map.get(private, :timing) || %{}
    info = Map.put(Map.get(timing, identifier) || %{}, key, value)

    %{
      resolution
      | private: Map.put(private, :timing, Map.put(timing, identifier, info))
    }
  end
end

defmodule RetWeb.Middleware.StartTiming do
  @moduledoc false

  import RetWeb.Middleware.TimingUtil, only: [add_timing_info: 4]

  @behaviour Absinthe.Middleware
  def call(resolution, _) do
    add_timing_info(resolution, resolution.definition.schema_node.identifier, :started_at, NaiveDateTime.utc_now())
  end
end

defmodule RetWeb.Middleware.EndTiming do
  @moduledoc false

  import RetWeb.Middleware.TimingUtil, only: [add_timing_info: 4]

  @behaviour Absinthe.Middleware
  def call(resolution, _) do
    add_timing_info(resolution, resolution.definition.schema_node.identifier, :ended_at, NaiveDateTime.utc_now())
  end
end

defmodule RetWeb.Middleware.InspectTiming do
  @moduledoc false

  @behaviour Absinthe.Middleware
  def call(resolution, _) do
    case resolution do
      %{private: %{timing: timing}} ->
        inspect_timing_info(timing)

      _ ->
        nil
    end

    resolution
  end

  defp inspect_timing_info(timing) do
    Enum.each(timing, fn item ->
      case item do
        {identifier, %{started_at: started_at, ended_at: ended_at}} ->
          diff = NaiveDateTime.diff(ended_at, started_at, :microsecond)
          IO.inspect(Atom.to_string(identifier) <> " took #{diff} microseconds to run.")

        {identifier, _} ->
          IO.puts(
            "Cannot log diff of identifier because it lacks timing info started_at and ended_at: " <>
              Atom.to_string(identifier)
          )

        _ ->
          nil
      end
    end)
  end
end
