defmodule RetWeb.Email do
  use Bamboo.Phoenix, view: RetWeb.EmailView

  def auth_email(to_address, signin_args) do
    new_email()
    |> to(to_address)
    |> from({"Hubs by Mozilla", from_address()})
    |> subject("Your Hubs Sign-In Link")
    |> text_body(
      "To sign-in to Hubs, please visit the link below. If you did not make this request, please ignore this e-mail.\n\n#{
        RetWeb.Endpoint.url()
      }/?#{URI.encode_query(signin_args)}"
    )
  end

  defp from_address do
    Application.get_env(:ret, __MODULE__)[:from]
  end
end
