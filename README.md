# Reticulum

A hybrid game networking and web API server, focused on Social Mixed Reality.

## Development

### 1. Install Prerequisite Packages:

#### PostgreSQL (recommended version 11.x):

Linux: Use your package manager

Windows: https://www.postgresql.org/download/windows/

Windows WSL: https://github.com/michaeltreat/Windows-Subsystem-For-Linux-Setup-Guide/blob/master/readmes/installs/PostgreSQL.md

#### Elixr + Phoenix

https://elixir-lang.org/install.html
https://hexdocs.pm/phoenix/installation.html

### 2. Setup Reticulum:

Run the following commands at the root of the reticulum directory:

1. `mix deps.get`
2. `mix ecto.create`
   - If step 2 fails, you may need to change the password for the `postgres` role to match the password configured `dev.exs`.
   - From within the `psql` shell, enter `ALTER USER postgres WITH PASSWORD 'postgres';`
3. from the `assets` directory, `npm install`
4. From the project directory `mkdir -p storage/dev`

### 3. Start Reticulum

Run `scripts/run.sh` if you have the hubs secret repo cloned. Otherwise `iex -S mix phx.server`

## Run Hubs Against a Local Reticulum Instance

### 0. Dependencies

[Install NodeJS](https://nodejs.org) if you haven't already. We recommend version 12 or above.

### 1. Setup the `hubs.local` hostname

When running the full stack for Hubs (which includes Reticulum) locally it is necessary to add a `hosts` entry pointing `hubs.local` to your local server's IP.
This will allow the CSP checks to pass that are served up by Reticulum so you can test the whole app. Note that you must also load hubs.local over https.

Example:

```
hubs.local 127.0.0.1
```

### 2. Setting up the Hubs Repository

Clone the Hubs repository and install the npm dependencies.

```bash
git clone https://github.com/mozilla/hubs.git
cd hubs
npm ci
```

### 3. Start the Hubs Webpack Dev Server

Because we are running Hubs against the local Reticulum client you'll need to use the `npm run local` command in the root of the `hubs` folder. This will start the development server on port 8080, but configure it to be accessed through Reticulum on port 4000.

### 4. Navigate To The Client Page

Once both the Hubs Webpack Dev Server and Reticulum server are both running you can navigate to the client by opening up:

https://hubs.local:4000?skipadmin

> The `skipadmin` is a temporary measure to bypass being redirected to the admin panel. Once you have logged in you will no longer need this.

### 5. Logging In

To log into Hubs we use magic links that are sent to your email. When you are running Reticulum locally we do not send those emails. Instead, you'll find the contents of that email in the Reticulum console output.

With the Hubs landing page open click the Sign In button at the top of the page. Enter an email address and click send.

Go to the reticulum terminal session and find a url that looks like https://hubs.local:4000/?auth_origin=hubs&auth_payload=XXXXX&auth_token=XXXX

Navigate to that url in your browser to finish signing in.

### 6. Creating an Admin User

After you've started Reticulum for the first time you'll likely want to create an admin user. Assuming you want to make the first account the admin, this can be done in the iex console using the following code:

```
Ret.Account |> Ret.Repo.all() |> Enum.at(0) |> Ecto.Changeset.change(is_admin: true) |> Ret.Repo.update!()
```

## Run Spoke Against a Local Reticulum Instance

1. Follow the steps above to setup Hubs
2. Clone and start spoke by running `./scripts/run_local_reticulum.sh` in the root of the spoke project
3. Navigate to https://hubs.local:4000/spoke

```elixir
%Ret.Scene{
  __meta__: #Ecto.Schema.Metadata<:loaded, "ret0", "scenes">,
  account: %Ret.Account{
    __meta__: #Ecto.Schema.Metadata<:loaded, "ret0", "accounts">,
    account_id: 744121974900391938,
    assets: #Ecto.Association.NotLoaded<association :assets is not loaded>,
    created_hubs: #Ecto.Association.NotLoaded<association :created_hubs is not loaded>,
    identity: #Ecto.Association.NotLoaded<association :identity is not loaded>,
    inserted_at: ~N[2020-07-10 20:18:12],
    is_admin: true,
    login: #Ecto.Association.NotLoaded<association :login is not loaded>,
    min_token_issued_at: ~U[1970-01-01 00:00:00Z],
    oauth_providers: #Ecto.Association.NotLoaded<association :oauth_providers is not loaded>,
    owned_files: #Ecto.Association.NotLoaded<association :owned_files is not loaded>,
    projects: #Ecto.Association.NotLoaded<association :projects is not loaded>,
    state: :enabled,
    updated_at: ~N[2020-07-10 20:18:42]
  },
  account_id: 744121974900391938,
  allow_promotion: true,
  allow_remixing: true,
  attribution: nil,
  attributions: %{
    "content" => [
      %{
        "author" => "mozillareality",
        "name" => "Building - square - illuminated",
        "url" => "https://sketchfab.com/models/0a32caef1dfe492294d9ccf81361b5e9"
        "url" => "https://sketchfab.com/models/1ba845e95a964809a9437c2a92ac59ab"
      },
      %{
        "author" => "Pedro França",
        "name" => "Wall Frame Paspatur",
        "url" => "https://sketchfab.com/3d-models/wall-frame-paspatur-18c4283aedea4c318dfb02765dd27ea3"
      },
      %{
        "author" => "shaylastewart",
        "name" => "mic stand texture for both characters",
        "url" => "https://sketchfab.com/models/c1b2d618c637446886d8c91778a7e6d5"
      }
    ],
    "creator" => "MissLiviRose"
  },
  description: nil,
  imported_from_host: "hubs.mozilla.com",
  imported_from_port: 443,
  imported_from_sid: "gZrvwOn",
  inserted_at: ~N[2020-07-10 20:35:37],
  model_owned_file: %Ret.OwnedFile{
    __meta__: #Ecto.Schema.Metadata<:loaded, "ret0", "owned_files">,
    account: #Ecto.Association.NotLoaded<association :account is not loaded>,
    account_id: 744121974900391938,
    content_length: 30541840,
    content_type: "application/octet-stream",
    inserted_at: ~N[2020-07-10 20:35:37],
    key: "6ffd80e9cc61fb2aeb7b04416b6749e9",
    owned_file_id: 744130733697662980,
    owned_file_uuid: "972b55e5-62d4-49ae-89c9-bebe51c69010",
    state: :active,
    updated_at: ~N[2020-07-10 20:35:37]
  },
  model_owned_file_id: 744130733697662980,
  name: "Conference Room A",
  parent_scene: nil,
  parent_scene_id: nil,
  parent_scene_listing: nil,
  parent_scene_listing_id: nil,
  project: nil,
  scene_id: 744130740693762055,
  scene_owned_file: %Ret.OwnedFile{
    __meta__: #Ecto.Schema.Metadata<:loaded, "ret0", "owned_files">,
    account: #Ecto.Association.NotLoaded<association :account is not loaded>,
    account_id: 744121974900391938,
    content_length: 52878,
    content_type: "application/json",
    inserted_at: ~N[2020-07-10 20:35:37],
    key: "b3903caf5c93af8632d134837643e29e",
    owned_file_id: 744130740240777222,
    owned_file_uuid: "67650482-af95-44e3-9a07-e9f48933b630",
    state: :active,
    updated_at: ~N[2020-07-10 20:35:37]
  },
  scene_owned_file_id: 744130740240777222,
  scene_sid: "zvzRZT3",
  screenshot_owned_file: %Ret.OwnedFile{
    __meta__: #Ecto.Schema.Metadata<:loaded, "ret0", "owned_files">,
    account: #Ecto.Association.NotLoaded<association :account is not loaded>,
    account_id: 744121974900391938,
    content_length: 426248,
    content_type: "image/jpeg",
    inserted_at: ~N[2020-07-10 20:35:37],
    key: "3ac89158331443b6466c3e53dd90febc",
    owned_file_id: 744130733982875653,
    owned_file_uuid: "2238b4f4-869d-49b9-ac27-c2a603070ff6",
    state: :active,
    updated_at: ~N[2020-07-10 20:35:37]
  },
  screenshot_owned_file_id: 744130733982875653,
  slug: "conference-room-a",
  state: :active,
  updated_at: ~N[2020-07-10 20:35:37]
}
```
