import EctoEnum

defenum(Ret.Hub.EntryMode, :hub_entry_mode, [:allow, :deny], schema: "ret0")
defenum(Ret.OwnedFile.State, :owned_file_state, [:active, :inactive, :removed], schema: "ret0")
defenum(Ret.Scene.State, :scene_state, [:active], schema: "ret0")
defenum(Ret.SceneListing.State, :scene_listing_state, [:active, :delisted], schema: "ret0")
