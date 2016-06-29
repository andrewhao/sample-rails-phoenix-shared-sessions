# Rails, meet Phoenix

### Migrating to Phoenix with Rails session sharing

You’ve resolved to build your company’s Next Big Thing in Phoenix and Elixir. That’s great! You’re facing a problem though - all user authentication and access concerns are performed on your Rails system, and the work to reimplement this in Phoenix is significant.

Fortunately for you, there is a great Phoenix plug to share session data between Rails and Phoenix. If you pull this off, you'll be able to build your new API on your Phoenix app, all while letting Rails handle user authentication and session management.

### Before we begin
In this scenario, you want to build out a new API in Phoenix that is consumed by your frontend single-page application, whose sessions are hosted on Rails. We'll call the Rails app `rails_app` and your new Phoenix app `phoenix_app`.

Additionally, each app will use a different subdomain. The Rails app will be deployed at the `www.myapp.com` subdomain. The Phoenix app will be deployed at the `api.myapp.com` subdomain.

We are going to take [Chris Constantin](https://github.com/cconstantin)'s excellent [`PlugRailsCookieSessionStore`](https://github.com/cconstantin/plug_rails_cookie_session_store) plug and integrate it into our Phoenix project. Both apps will be configured with identical cookie domains, encryption salts, signing salts, and security tokens.

In the examples that follow, I'll be using the latest versions of each framework at the time of writing, Rails 4.2 and Phoenix 1.2.

### Cookie-based session storage

Our session data is stored on the client in a secure, encrypted, validated cookie. We won't cover the basics of cookies here, but [you can read more about them here](http://www.justinweiss.com/articles/how-rails-sessions-work/).

Our approach will only work if your current Rails system utilizes cookie-based sessions. We will not cover the use case with a database-backed session store in SQL, Redis, or Memcache.

### Step 1: Configure Rails accordingly

#### Configure the cookie store

Let's set up your Rails app to use a JSON cookie storage format:

```ruby
# config/initializer/session_store.rb

# Use cookie session storage in JSON format. Here, we scope the cookie to the root domain.
Rails.application.config.session_store :cookie_store, key: '_rails_app_session', domain: ".#{ENV['DOMAIN']}"
Rails.application.config.action_dispatch.cookies_serializer = :json

# These salts are optional, but it doesn't hurt to explicitly configure them the same between the two apps.
Rails.application.config.action_dispatch.encrypted_cookie_salt = ENV['SESSION_ENCRYPTED_COOKIE_SALT']
Rails.application.config.action_dispatch.encrypted_signed_cookie_salt = ENV['SESSION_ENCRYPTED_SIGNED_COOKIE_SALT']

```

Your app may not be configured with a `SESSION_ENCRYPTED_COOKIE_SALT` and `SESSION_ENCRYPTED_SIGNED_COOKIE_SALT`. You may generate a pair with any random values.

[Some speculate](http://nipperlabs.com/rails-secretkeybase) that Rails does not require the two salts by default because the `SECRET_KEY_BASE` is sufficiently long enough to not require a salt. In our example, we choose to supply them anyways to be explicit.

Another important value to note here is that we have chosen a key for our session cookie - `_rails_app_session`. This value will be the shared cookie key for both apps.

### Step 2: Configure the plug for Phoenix

Turning our attention to our Phoenix app, in the `mix.exs` file, add the library dependency:

```elixir
# mix.exs
defmodule PhoenixApp
  defp deps do
    # snip
    {:plug_rails_cookie_session_store, "~> 0.1"},
    # snip
  end
end
```

Then run `mix deps.get` to fetch the new library.

Now in your `web/phoenix_app/endpoint.ex` file, remove the configuration for the existing session store and add the configuration for the Rails session store.

```elixir
# lib/phoenix_app/endpoint.ex
defmodule PhoenixApp.Endpoint do
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
    # Specifies the matching rules on the hostname that this cookie will be valid for
    domain: ".#{System.get_env("DOMAIN")}",
    signing_salt: System.get_env("SESSION_ENCRYPTED_SIGNED_COOKIE_SALT"),
    encryption_salt: System.get_env("SESSION_ENCRYPTED_COOKIE_SALT"),
    key_iterations: 1000,
    key_length: 64,
    key_digest: :sha,
    # Specify a JSON serializer to use on the session
    serializer: Poison
end

```

We set a `DOMAIN` environment variable with the value
`myapp.com`. The goal is for these two apps to be able to be deployed at any subdomain that ends in `myapp.com`, and still be able to share the cookie.

The `secure` flag configures the app to send a secure cookie, which only is served over SSL HTTPS connections. It is highly recommended for your site; if you haven't upgraded to SSL, you should do so now!

Our cookies are signed such that their origins are guaranteed to have been computed from our app(s). This is done for free with Rails (and Phoenix's) session libraries. The signature is derived from the `secret_key_base` and `signing_salt`.

The `encrypt` flag encrypts the contents of the cookie's value with an encryption key derived from `secret_key_base` and `encryption_salt`. This should always be set to `true`.

`key_iterations`, `key_length` and `key_digest` are configurations that dictate how the signing and encryption keys are derived. These are [configured to match Rails' defaults](https://github.com/rails/rails/blob/4-2-stable/railties/lib/rails/application.rb) (see also: [defaults](https://github.com/rails/rails/blob/4-2-stable/activesupport/lib/active_support/key_generator.rb)). Unless your Rails app has custom configurations for these values, you should leave them be.

### Step 3: Configure both apps to read from the new environment variables

Be sure your development and production versions of your app are configured with identical values for `DOMAIN`, `SESSION_ENCRYPTED_COOKIE_SALT` and `SESSION_ENCRYPTED_SIGNED_COOKIE_SALT`. You'll want to make sure your production apps store identical key-value pairs.

### Step 4: Change Phoenix controllers to verify sessions based on session data.

Now when the Phoenix app receives incoming requests, it can simply look up user session data in the session cookie to determine whether the user is logged in, and who that user is.

In this example, our Rails app implements user auth with Devise and Warden. We know that Warden stores the user ID and a segment of the password hash in the `warden.user.user.key` session variable.

Here's what the raw session data looks like when the `PlugRailsCookieSessionStore` extracts it from the cookie:

```elixir
%{"_csrf_token" => "ELeSt4MBUINKi0STEBpslw3UevGZuVLUx5zGVP5NlQU=",
  "session_id" => "17ec9b696fe76ba4a777d625e57f3521",
  "warden.user.user.key" => [[2], "$2a$10$R/3NKl9KQViQxY8eoMCIp."]}
```

```elixir
defmodule PhoenixApp.SomeApiResourceController do
  use PhoenixApp.Web, :controller

  def index(conn, _params) do
    {:ok, user_id} = load_user(conn)

    conn
    |> assign(:user_id, user_id)
    |> render("index.html")
  end

  plug :verify_session

  # If we've found a user, then allow the request to continue.
  # Otherwise, halt the request and return a 401
  defp verify_session(conn, _) do
    case load_user(conn) do
      {:ok, user_id} -> conn
      {:error, _} -> conn |> send_resp(401, "Unauthorized") |> halt
    end
  end

  defp load_user(conn) do
    # => The Warden user storage scheme: [user_id, password_hash_truncated]
    # [[1], "$2a$10$vnx35UTTJQURfqbM6srv3e"]
    warden_key = conn |> get_session("warden.user.user.key")

    case warden_key do
      [[user_id], _] -> {:ok, user_id}
      _ -> {:error, :not_found}
    end
  end
end
```

A very naive plug implementation simply renders a 401 if the session key is not found in the session, otherwise it allows the request through.

### Step 5: Move session concerns into its own module

Let's move session concerns around session parsing out of the controller into its own `Session` module. Additionally, we include two helpers, `current_user/1` and `logged_in?/1`.

```elixir
# web/models/session.ex
defmodule PhoenixApp.Session do
  use PhoenixApp.Web, :controller
  def current_user(conn) do
    # Our app's concept of a User is merely whatever is stored in the
    # Session key. In the future, we could then use this as the delegation
    # point to fetch more details about the user from a backend store.
    case load_user(conn) do
      {:ok, user_id} -> user_id
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
```

This leaves the controller looking skinnier, implementing only the Plug. Extracted methods are delegated to the new `Session` module.

```elixir
defmodule PhoenixApp.SomeApiResourceController do
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
```

Finally, we implement some nice helpers for your APIs:

```elixir
# web/web.ex

def view do
  quote do
    # snip
    import PhoenixApp.Session
  end
end
```

This gives you the ability to call `logged_in?(@conn)` and `current_user(@conn)` from within your views, should you desire to.

### Step 6: Fetching additional information from the backend

Let's enhance our `Session` module with the capability to fetch additional information from another resource.

In this case, we'll model a call an external User API to fetch extended data about the User, potentially with some sensitive information (that's why we didn't want to serialize it into the session).

```elixir
# web/models/user.ex
defmodule PhoenixApp.User do
  # Gets some user identity information like email, avatar image.
  # For this example, we'll use a random user generator.
  #
  # This example hits an API, but this could just as easily be something that hits
  # the database, or Redis, or some cache.
  def fetch(user_id) do
    %{ body: body } = HTTPotion.get("https://randomuser.me/api?seed=#{user_id}")
    [result | _ ] = body |> Poison.decode! |> Map.get("results")
    result
  end
end
```

Now our `Session` can be extended to return the proper `User`, which may provide more utility to us as we implement our Phoenix feature.

```elixir
defmodule PhoenixApp.Session do
  use PhoenixApp.Web, :controller
  alias PhoenixApp.User

  def current_user(conn) do
    case load_user(conn) do
      # Changed current_user/1 to now return a User or a nil.
      {:ok, user_id} -> user_id |> User.fetch
      {:error, :not_found} -> nil
    end
  end

  # snip
end
```

#### Here's the two apps in action:

![Flipping between the two apps, logged in and out.](http://i.imgur.com/Vu72x7C.gif)

### Heroku deployment gotchas

If you are deploying this to Heroku with the popular [Heroku Elixir buildpack](git@github.com:HashNuke/heroku-buildpack-elixir.git), please be aware that adding or changing environment variables that are required at build time require that the new environment variables outlined here are added to your `elixir_buildpack.config` file in your repository.

```elixir
# elixir_buildpack.config
config_vars_to_export=(SECRET_KEY_BASE SESSION_ENCRYPTED_COOKIE_SALT SESSION_ENCRYPTED_SIGNED_COOKIE_SALT DOMAIN)
```

### Caveats and considerations

#### CSRF incompatibilites

At the time of this writing, Phoenix and Rails overwrite each others' session CSRF tokens with incompatible token schemes. This means that you are not able to make remote POST or PUT requests across the apps with CSRF protection turned on. Our current approach will work best with a read-only API, at the moment.

#### Be judicious about what you store in a cookie

Cookies themselves have their own strengths and drawbacks. We should note that you should be judicious about the amount of [data you store in a session](http://guides.rubyonrails.org/security.html#replay-attacks-for-cookiestore-sessions) (hint: only the bare minimum, and nothing sensitive).

The OWASP guidelines also provide some [general security practices around cookie session storage](https://www.owasp.org/index.php/Session_Management_Cheat_Sheet).

#### Moving beyond session sharing

Even though this scheme may work in the short run, coupling our apps at this level in the long run will result in headaches as the apps are coupled to intricate session implementation details. If, in the long run, you wanted to continue scaling out your Phoenix app ecosystem, you may want to look into the following authentication patterns, both of which move your system toward a microservices architecture.

1) Develop an [API gateway](http://microservices.io/patterns/apigateway.html) whose purpose is to be the browser's buffer to your internal service architecture. This one gateway is responsible for identity access and control, decrypting session data and proxying requests to an umbrella of internal services (which may be Rails or Phoenix). Internal services may receive user identities in unencrypted form.

2) Consider implementing a [JWT token implementation](https://jwt.io/) across your apps, in which [all session and authorization claims are stored in the token itself, and encrypted in the client and server.](https://auth0.com/blog/2014/01/07/angularjs-authentication-with-cookies-vs-token/). This scheme may still rely on cookies (you may store the token in a cookie, or pass it around in an HTTP header). The benefits of this scheme is the ability for your app(s) to manage identity and authentication claims on their own without having to verify against a third party. Drawbacks of this scheme are [the difficulty around revoking or expiring sessions](http://blog.prevoty.com/does-jwt-put-your-web-app-at-risk).

Each of these approaches is not without overhead and complexity; be sure to do your homework before your proceed.

### Conclusion

That's it! I hope I've illustrated a quick and easy way to get a working Phoenix app sharing sessions with Rails app(s), should you decide to prototype one in your existing system. I've also pushed up a [sample app if you want to cross-reference the code](https://github.com/andrewhao/sample-rails-phoenix-shared-sessions/). Good luck!
