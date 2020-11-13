defimpl Canada.Can, for: Ret.Api.Credentials do
  import Canada, only: [can?: 2]
  alias Ret.{Account, Hub}
  alias Ret.Api.{Credentials, Scopes}

  def can?(
        %Credentials{is_revoked: true},
        _action,
        _resource
      ) do
    false
  end

  def can?(
        %Credentials{subject_type: :app, scopes: scopes},
        :get_rooms_created_by,
        %Account{} = account
      ) do
    Scopes.read_rooms() in scopes and can?(:reticulum_app_token, get_rooms_created_by(account))
  end

  def can?(
        %Credentials{subject_type: :account, account: subject, scopes: scopes},
        :get_rooms_created_by,
        %Account{} = account
      ) do
    Scopes.read_rooms() in scopes and can?(subject, get_rooms_created_by(account))
  end

  def can?(
        %Credentials{subject_type: :app, scopes: scopes},
        :get_favorite_rooms_of,
        %Account{} = account
      ) do
    Scopes.read_rooms() in scopes and can?(:reticulum_app_token, get_favorite_rooms_of(account))
  end

  def can?(
        %Credentials{subject_type: :account, account: subject, scopes: scopes},
        :get_favorite_rooms_of,
        %Account{} = account
      ) do
    Scopes.read_rooms() in scopes and can?(subject, get_favorite_rooms_of(account))
  end

  def can?(
        %Credentials{subject_type: :app, scopes: scopes},
        :get_public_rooms,
        _
      ) do
    Scopes.read_rooms() in scopes and can?(:reticulum_app_token, get_public_rooms(nil))
  end

  def can?(
        %Credentials{subject_type: :account, account: subject, scopes: scopes},
        :get_public_rooms,
        _
      ) do
    Scopes.read_rooms() in scopes and can?(subject, get_public_rooms(nil))
  end

  def can?(
        %Credentials{subject_type: :app, scopes: scopes},
        :create_room,
        _
      ) do
    Scopes.write_rooms() in scopes && can?(:reticulum_app_token, create_hub(nil))
  end

  def can?(
        %Credentials{subject_type: :account, account: subject, scopes: scopes},
        :create_room,
        _
      ) do
    Scopes.write_rooms() in scopes && can?(subject, create_hub(nil))
  end

  def can?(%Credentials{subject_type: :app, scopes: scopes}, :embed_hub, %Hub{} = hub) do
    Scopes.read_rooms() in scopes && can?(:reticulum_app_token, embed_hub(hub))
  end

  def can?(%Credentials{subject_type: :account, account: subject, scopes: scopes}, :embed_hub, %Hub{} = hub) do
    Scopes.read_rooms() in scopes && can?(subject, embed_hub(hub))
  end

  def can?(
        %Credentials{subject_type: :app, scopes: scopes},
        :update_room,
        %Hub{} = hub
      ) do
    Scopes.write_rooms() in scopes && can?(:reticulum_app_token, update_hub(hub))
  end

  def can?(
        %Credentials{subject_type: :account, account: subject, scopes: scopes},
        :update_room,
        %Hub{} = hub
      ) do
    Scopes.write_rooms() in scopes && can?(subject, update_hub(hub))
  end

  def can?(_, _, _), do: false
end
