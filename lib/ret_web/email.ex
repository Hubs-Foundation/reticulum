defmodule RetWeb.Email do
  use Bamboo.Phoenix, view: RetWeb.EmailView

  def auth_email(to_address) do
    new_email
    |> to(to_address)
    |> from(from_address)
    |> subject("Your Hubs Sign-In Link")
    |> text_body("Hello world")
  end

  defp from_address do
    Application.get_env(:ret, __MODULE__)[:from]
  end
end
