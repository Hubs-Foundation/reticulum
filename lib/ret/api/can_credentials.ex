defimpl Canada.Can, for: Ret.Api.Credentials do
  alias Ret.{Account}
  alias Ret.Api.{Credentials, Scopes}

  def can?(
        %Credentials{resource: :reticulum_app_token, scopes: scopes},
        action,
        %Account{}
      )
      when action in [:get_rooms_created_by, :get_favorite_rooms_of] do
    Scopes.read_rooms() in scopes
  end

  def can?(
        %Credentials{resource: %Account{} = account, scopes: scopes},
        action,
        %Account{} = account
      )
      when action in [:get_rooms_created_by, :get_favorite_rooms_of] do
    Scopes.read_rooms() in scopes
  end

  def can?(
        %Credentials{scopes: scopes},
        :get_public_rooms,
        _
      ) do
    IO.inspect("hello world")
    Scopes.read_rooms() in scopes
  end

  def can?(_, _, _), do: false
end
