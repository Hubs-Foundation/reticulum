defimpl Canada.Can, for: Ret.Api.Credentials do
  import Canada, only: [can?: 2]
  alias Ret.{Account, Hub}
  alias Ret.Api.{Credentials, Scopes}

  def can?(
        %Credentials{resource: resource, scopes: scopes},
        :get_rooms_created_by,
        %Account{} = account
      ) do
    Scopes.read_rooms() in scopes and can?(resource, get_rooms_created_by(account))
  end

  def can?(
        %Credentials{resource: resource, scopes: scopes},
        :get_favorite_rooms_of,
        %Account{} = account
      ) do
    Scopes.read_rooms() in scopes and can?(resource, get_favorite_rooms_of(account))
  end

  def can?(
        %Credentials{resource: resource, scopes: scopes},
        :get_public_rooms,
        _
      ) do
    Scopes.read_rooms() in scopes and can?(resource, get_public_rooms(nil))
  end

  def can?(
        %Credentials{resource: resource, scopes: scopes},
        :create_room,
        _
      ) do
    Scopes.write_rooms() in scopes && can?(resource, create_hub(nil))
  end

  def can?(%Credentials{resource: resource, scopes: scopes}, :embed_hub, %Hub{} = hub) do
    Scopes.read_rooms() in scopes && can?(resource, embed_hub(hub))
  end

  def can?(
        %Credentials{resource: resource, scopes: scopes},
        :update_room,
        %Hub{} = hub
      ) do
    Scopes.read_rooms() in scopes && can?(resource, update_hub(hub))
  end

  def can?(_, _, _), do: false
end
