defmodule PhoenixApp.PageController do
  use PhoenixApp.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  plug :verify_session

  defp load_user(conn) do
    IO.inspect get_session(conn, "warden.user.user.key")
    # => The Warden user storage scheme: user_id, password_hash_truncated
    # [[1], "$2a$10$vnx35UTTJQURfqbM6srv3e"]
    conn |> get_session("warden.user.user.key")
  end

  defp verify_session(conn, _) do
    user_id = load_user
    case user_id do
      nil -> conn |> send_resp(401, "Unauthorized") |> halt
      _ -> conn
    end
  end
end
