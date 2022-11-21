defmodule Ret.SchemaTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ret.{DummySchema, DummyStruct, Schema}
  require Ret.Schema

  describe "is_schema/1" do
    test "with an Ecto schema" do
      assert true === Schema.is_schema(%DummySchema{})
    end

    test "with a non-schema struct" do
      assert false === Schema.is_schema(%DummyStruct{})
    end

    property "with a non-struct map" do
      check all map <-
                  string(:printable, max_length: 3)
                  |> map(&String.to_atom/1)
                  |> map_of(nil) do
        assert false === Schema.is_schema(map)
      end
    end

    property "with a non-map value" do
      check all non_map <- filter(term(), &(not is_map(&1))) do
        assert false === Schema.is_schema(non_map)
      end
    end
  end

  describe "is_serial_id/1" do
    property "with a positive integer" do
      check all pos_integer <- positive_integer() do
        assert true === Schema.is_serial_id(pos_integer)
      end
    end

    test "with zero" do
      assert false === Schema.is_serial_id(0)
    end

    property "with a negative integer" do
      check all neg_integer <- map(positive_integer(), &(-&1)) do
        assert false === Schema.is_serial_id(neg_integer)
      end
    end

    property "with a non-integer value" do
      check all non_integer <- filter(term(), &(not is_integer(&1))) do
        assert false === Schema.is_serial_id(non_integer)
      end
    end
  end
end
