defimpl Canada.Can, for: Ret.Api.Credentials do
  import Canada, only: [can?: 2]
  alias Ret.{Account, Hub}
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
    Scopes.read_rooms() in scopes
  end

  def can?(
        %Credentials{scopes: scopes},
        :create_room,
        _
      ) do
    Scopes.write_rooms() in scopes
  end

  def can?(%Credentials{resource: :reticulum_app_token, scopes: scopes}, :embed_hub, %Hub{}) do
    Scopes.read_rooms() in scopes
  end

  def can?(%Credentials{resource: %Account{} = account, scopes: scopes}, :embed_hub, %Hub{} = hub) do
    Scopes.read_rooms() in scopes && can?(account, embed_hub(hub))
  end

  def can?(
        %Credentials{resource: :reticulum_app_token, scopes: scopes},
        :update_room,
        %Hub{}
      ) do
    Scopes.read_rooms() in scopes
  end

  def can?(
        %Credentials{resource: %Account{} = account, scopes: scopes},
        :update_room,
        %Hub{} = hub
      ) do
    Scopes.read_rooms() in scopes && can?(account, update_hub(hub))
  end

  def can?(_, _, _), do: false
end
