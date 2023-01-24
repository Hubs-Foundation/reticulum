defmodule Ret.Application do
  use Application

  import Cachex.Spec, only: [expiration: 1, fallback: 1, warmer: 1]

  def start(_type, _args) do
    Application.load(:ret)
    EctoBootMigration.start_dependencies()

    repos_pids =
      Ret.Locking.exec_if_session_lockable("ret_migration", fn ->
        repos_pids = EctoBootMigration.start_repos([Ret.SessionLockRepo])

        # Note the main Repo database is used here, since the session locking database
        # name may be a proxy database in pgbouncer which doesn't actually exist.
        db_name = Application.get_env(:ret, Ret.Repo)[:database]

        # Can't check mix_env here, so check db name
        if db_name !== "ret_test" do
          coturn_enabled = Ret.Coturn.enabled?()

          Ecto.Adapters.SQL.query!(Ret.SessionLockRepo, "CREATE SCHEMA IF NOT EXISTS ret0")

          if coturn_enabled do
            Ecto.Adapters.SQL.query!(Ret.SessionLockRepo, "CREATE SCHEMA IF NOT EXISTS coturn")
          end

          Ecto.Adapters.SQL.query!(
            Ret.SessionLockRepo,
            "ALTER DATABASE #{db_name} SET search_path TO ret0"
          )

          priv_path = Path.join(["#{:code.priv_dir(:ret)}", "repo", "migrations"])

          # Disallow stop of the application via SIGTERM until migrations are finished.
          #
          # If application is killed mid-migration, then it's possible for schema migrations
          # table to not accurately reflect the migrations which have ran.
          Ret.DelayStopSignalHandler.delay_stop()

          try do
            Ecto.Migrator.run(Ret.SessionLockRepo, priv_path, :up, all: true, prefix: "ret0")
          after
            Ret.DelayStopSignalHandler.allow_stop()
          end

          repos_pids
        end
      end)

    if repos_pids do
      # Ensure there are some TURN secrets in the database, so that if system is idle
      # the cron isn't indefinitely skipped and nobody can join rooms.
      Ret.Coturn.rotate_secrets(true, Ret.SessionLockRepo)

      EctoBootMigration.stop_repos(repos_pids)
    end

    :ok = Ret.Statix.connect()
    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)

    children = [
      {Phoenix.PubSub, [name: Ret.PubSub, adapter: Phoenix.PubSub.PG2, pool_size: 4]},
      Ret.Repo,
      RetWeb.Endpoint,
      RetWeb.Presence,
      Ret.Scheduler,
      Ret.RoomAssignerMonitor,
      %{
        id: :rate_limit,
        start:
          {PlugAttack.Storage.Ets, :start_link,
           [RetWeb.RateLimit.Storage, [clean_period: 60_000]]}
      },
      %{
        id: :media_url_cache,
        start:
          {Cachex, :start_link,
           [
             :media_urls,
             [
               expiration: expiration(default: :timer.minutes(5)),
               fallback: fallback(default: &Ret.MediaResolver.resolve/1)
             ]
           ]}
      },
      %{
        id: :media_search_cache,
        start:
          {Cachex, :start_link,
           [
             :media_search_results,
             [
               expiration: expiration(default: :timer.minutes(5)),
               fallback: fallback(default: &Ret.MediaSearch.search/1)
             ]
           ]}
      },
      %{
        id: :media_search_cache_long,
        start:
          {Cachex, :start_link,
           [
             :media_search_results_long,
             [
               expiration: expiration(default: :timer.hours(24)),
               fallback: fallback(default: &Ret.MediaSearch.search/1)
             ]
           ]}
      },
      %{
        id: :discord_api_cache,
        start:
          {Cachex, :start_link,
           [
             :discord_api,
             [
               expiration: expiration(default: :timer.minutes(1)),
               fallback: fallback(default: &Ret.DiscordClient.api_request/1)
             ]
           ]}
      },
      %{
        id: :slack_api_cache,
        start:
          {Cachex, :start_link,
           [
             :slack_api,
             [
               expiration: expiration(default: :timer.minutes(1)),
               fallback: fallback(default: &Ret.SlackClient.api_request/1)
             ]
           ]}
      },
      %{
        id: :app_config_cache,
        start:
          {Cachex, :start_link,
           [
             :app_config,
             [
               expiration: expiration(default: :timer.seconds(10)),
               fallback: fallback(default: &Ret.AppConfig.fetch_config/1)
             ]
           ]}
      },
      %{
        id: :app_config_value_cache,
        start:
          {Cachex, :start_link,
           [
             :app_config_value,
             [
               expiration: expiration(default: :timer.seconds(15)),
               fallback: fallback(default: &Ret.AppConfig.get_config_value/1)
             ]
           ]}
      },
      %{
        id: :app_config_owned_file_uri_cache,
        start:
          {Cachex, :start_link,
           [
             :app_config_owned_file_uri,
             [
               expiration: expiration(default: :timer.seconds(15)),
               fallback: fallback(default: &Ret.AppConfig.get_config_owned_file_uri/1)
             ]
           ]}
      },
      %{
        id: :asset_cache,
        start: {Cachex, :start_link, [:assets, []]}
      },
      %{
        id: :page_chunk_cache,
        start:
          {Cachex, :start_link,
           [
             :page_chunks,
             [
               warmers: [warmer(module: Ret.PageOriginWarmer)]
             ]
           ]}
      },
      %{
        id: :janus_load_status,
        start:
          {Cachex, :start_link,
           [
             :janus_load_status,
             [
               warmers: [warmer(module: Ret.JanusLoadStatus)]
             ]
           ]}
      },
      %{
        id: :storage_used,
        start:
          {Cachex, :start_link,
           [
             :storage_used,
             [
               warmers: [warmer(module: Ret.StorageUsed)]
             ]
           ]}
      },
      %{
        id: :coturn_secret,
        start:
          {Cachex, :start_link,
           [
             :coturn_secret,
             [
               expiration: expiration(default: :timer.minutes(1)),
               fallback: fallback(default: &Ret.Coturn.latest_secret_commit/1)
             ]
           ]}
      },
      %{
        id: :whats_new_cache,
        start:
          {Cachex, :start_link,
           [
             :whats_new,
             [
               expiration: expiration(default: :timer.minutes(1)),
               fallback:
                 fallback(default: &RetWeb.Api.V1.WhatsNewController.fetch_pull_requests/1)
             ]
           ]}
      }
    ]

    Supervisor.start_link(children, name: Ret.Supervisor, strategy: :one_for_one)
  end

  def config_change(changed, _new, removed) do
    RetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
