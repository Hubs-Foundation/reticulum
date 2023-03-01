defmodule RetWeb.EntityTestUtils do
  defp local_file(filename) do
    Path.join(Path.dirname(__ENV__.file), filename)
  end

  def read_json(filename) do
    filename
    |> local_file()
    |> File.read!()
    |> Jason.decode!()
  end
end
