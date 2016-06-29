defmodule PhoenixApp.Session do
  use PhoenixApp.Web, :controller
  alias PhoenixApp.User
  
  def current_user(conn) do
    # Our app's concept of a User is merely whatever is stored in the
    # Session key. In the future, we could then use this as the delegation
    # point to fetch more details about the user from a backend store.
    case load_user(conn) do
      {:ok, user_id} -> user_id |> User.fetch
      {:error, :not_found} -> nil
    end
  end

  def logged_in?(conn) do
    !!current_user(conn)
  end

  def load_user(conn) do
    # => The Warden user storage scheme: [user_id, password_hash_truncated]
    # [[1], "$2a$10$vnx35UTTJQURfqbM6srv3e"]
    warden_key = conn |> get_session("warden.user.user.key")

    case warden_key do
      [[user_id], _] -> {:ok, user_id}
      _ -> {:error, :not_found}
    end
  end
end
