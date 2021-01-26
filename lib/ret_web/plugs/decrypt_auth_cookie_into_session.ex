defmodule RetWeb.Plugs.DecryptAuthCookieIntoSession do
  def init([]), do: []

  def call(conn, []) do
    conn = Plug.Conn.fetch_cookies(conn, encrypted: "guardian_default_token")
    # Plug.Conn.fetch_cookies decrypts into conn.cookies
    # But Guardian.Plug.VerifyCookie reads from conn.req_cookies
    # so instead we put token into a session and use
    # Guardian.Plug.VerifySession
    conn = Plug.Conn.fetch_session(conn)
    conn = Plug.Conn.put_session(conn, "guardian_default_token", conn.cookies["guardian_default_token"] || nil)
    conn
  end
end
