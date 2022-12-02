import EctoEnum

defenum(Ret.Hub.EntryMode, :hub_entry_mode, [:allow, :invite, :deny], schema: "ret0")
defenum(Ret.HubInvite.State, :hub_invite_state, [:active, :revoked], schema: "ret0")
defenum(Ret.HubBinding.Type, :hub_binding_type, [:discord, :slack], schema: "ret0")

defenum(Ret.OAuthProvider.Source, :oauth_provider_source, [:discord, :slack, :twitter],
  schema: "ret0"
)

defenum(Ret.OwnedFile.State, :owned_file_state, [:active, :inactive, :removed], schema: "ret0")
defenum(Ret.Scene.State, :scene_state, [:active, :removed], schema: "ret0")
defenum(Ret.SceneListing.State, :scene_listing_state, [:active, :delisted], schema: "ret0")
defenum(Ret.Avatar.State, :avatar_state, [:active, :removed], schema: "ret0")

defenum(Ret.AvatarListing.State, :avatar_listing_state, [:active, :delisted, :removed],
  schema: "ret0"
)

defenum(Ret.Account.State, :account_state, [:enabled, :disabled], schema: "ret0")
defenum(Ret.Asset.Type, :asset_type, [:image, :video, :model, :audio], schema: "ret0")
defenum(Ret.Api.TokenSubjectType, :api_token_subject_type, [:app, :account], schema: "ret0")
defenum(Ret.Api.ScopeType, :api_scope_type, Ret.Api.Scopes.all_scopes(), schema: "ret0")
