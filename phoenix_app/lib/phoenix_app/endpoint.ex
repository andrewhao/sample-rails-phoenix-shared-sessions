defmodule PhoenixApp.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_app

  socket "/socket", PhoenixApp.UserSocket

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/", from: :phoenix_app, gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    # Remove the original cookie store that comes with Phoenix, out of the box.
    # store: :cookie,
    # key: "_phoenix_app_key",
    # signing_salt: "M8emDP0h"
    store: PlugRailsCookieSessionStore,
    # Decide on a shared key for your cookie. Oftentimes, this should
    # mirror your Rails app session key
    key: "_rails_app_session",
    secure: true,
    encrypt: true,
    domain: ".#{System.get_env("DOMAIN")}",
    signing_salt: System.get_env("SESSION_ENCRYPTED_SIGNED_COOKIE_SALT"),
    encryption_salt: System.get_env("SESSION_ENCRYPTED_COOKIE_SALT"),
    key_iterations: 1000,
    key_length: 64,
    key_digest: :sha,
    serializer: Poison

  plug PhoenixApp.Router
end
