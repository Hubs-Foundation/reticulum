defmodule Ret.Migration do
  defmacro __using__(_) do
    quote do
      use Ecto.Migration

      def after_begin() do
        repo().query!("set search_path=ret0, public")
      end
    end
  end
end
