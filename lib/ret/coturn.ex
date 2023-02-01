defmodule Ret.Coturn do
  # Adds a new secret, and removes secrets older than 15 minutes since a new one is generated every five.
  # Note this is safe to run on a multi-node cluster since coturn respects all secrets in the db.
  def rotate_secrets(force \\ false, repo \\ Ret.Repo) do
    # Don't perform database cron if turn is disabled or nobody is connected, to prevent un-pausing db.
    if enabled?() && (force || RetWeb.Presence.has_present_members?()) do
      Ecto.Adapters.SQL.query!(
        repo,
        "INSERT INTO coturn.turn_secret (realm, value, inserted_at, updated_at) values ($1, $2, now(), now())",
        [realm(), SecureRandom.hex()]
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "DELETE FROM coturn.turn_secret WHERE inserted_at < now() - interval '15 minutes'"
      )
    end
  end

  def generate_credentials do
    {_, coturn_secret} = Cachex.fetch(:coturn_secret, :coturn_secret)

    # Credentials are good for two minutes, since we connect immediately.
    username = "#{Timex.now() |> Timex.shift(minutes: 2) |> Timex.to_unix()}:coturn"

    credential =
      :hmac
      |> :crypto.mac(:sha, coturn_secret, username)
      |> :base64.encode()

    {username, credential}
  end

  def latest_secret_commit(_key) do
    if enabled?() do
      %Postgrex.Result{rows: [[secret]]} =
        Ecto.Adapters.SQL.query!(
          Ret.Repo,
          "SELECT value FROM coturn.turn_secret WHERE realm = $1 ORDER BY inserted_at DESC LIMIT 1",
          [realm()]
        )

      {:commit, secret}
    else
      {:commit, nil}
    end
  end

  def enabled? do
    !!realm()
  end

  defp realm do
    Application.get_env(:ret, __MODULE__)[:realm]
  end
end
