import EctoEnum

defenum(Ret.Hub.EntryMode, :hub_entry_mode, [:allow, :deny], schema: "ret0")
defenum(Ret.HubBinding.Type, :hub_binding_type, [:discord, :slack], schema: "ret0")
defenum(Ret.OAuthProvider.Source, :oauth_provider_source, [:discord, :slack, :twitter], schema: "ret0")
defenum(Ret.OwnedFile.State, :owned_file_state, [:active, :inactive, :removed], schema: "ret0")
defenum(Ret.Scene.State, :scene_state, [:active, :removed], schema: "ret0")
defenum(Ret.SceneListing.State, :scene_listing_state, [:active, :delisted], schema: "ret0")
defenum(Ret.Avatar.State, :avatar_state, [:active, :removed], schema: "ret0")
defenum(Ret.AvatarListing.State, :avatar_listing_state, [:active, :delisted, :removed], schema: "ret0")
defenum(Ret.Asset.Type, :asset_type, [:image, :video, :model], schema: "ret0")
defenum(Ret.Hub.Privacy, :hub_privacy, [:public, :private, :invite_only], schema: "ret0")
