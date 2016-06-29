defmodule PhoenixApp.PageController do
  use PhoenixApp.Web, :controller
  alias PhoenixApp.Session

  def index(conn, _params) do
    IO.inspect conn.private.plug_session
    user_id = Session.current_user(conn)

		conn
		|> assign(:user_id, user_id)
		|> render("index.html")
  end

  plug :verify_session

  # Future refinements could extract this into its own Plug file.
  defp verify_session(conn, _) do
    case Session.logged_in?(conn) do
      false -> conn |> send_resp(401, "Unauthorized") |> halt
      _ -> conn
    end
  end
end
