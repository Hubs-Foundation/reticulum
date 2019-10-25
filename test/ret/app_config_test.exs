defmodule Ret.AppConfigTest do
  use Ret.DataCase

  test "should construct correct app config structure" do
    %Ret.AppConfig{key: "foo", value: %{value: "bar"}} |> Ret.Repo.insert()
    %Ret.AppConfig{key: "spam|eggs", value: %{value: "baz"}} |> Ret.Repo.insert()
    %Ret.AppConfig{key: "spam|bacon", value: %{value: "baz"}} |> Ret.Repo.insert()
    %Ret.AppConfig{key: "spam|cheese|bacon", value: %{value: "buz"}} |> Ret.Repo.insert()

    IO.inspect(["BPDEBUG config", Ret.AppConfig.get_config()])

    expected = %{
      "foo" => "bar",
      "spam" => %{
        "eggs" => "baz",
        "bacon" => "baz",
        "cheese" => %{"bacon" => "buz"}
      }
    }

    set1 = Ret.AppConfig.get_config() |> MapSet.new()
    set2 = expected |> MapSet.new()
    true = MapSet.subset?(set1, set2)
    true = MapSet.subset?(set2, set1)
  end
end
