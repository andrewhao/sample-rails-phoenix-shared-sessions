---
layout: post
title: "Migrating to Phoenix with Rails session sharing"
date: 2016-06-24 13:31:06 -0700
comments: true
categories:
- Elixir
- Phoenix
- Rails
---

You've heard the buzz about Phoenix and Elixir - about its fantastic concurrency features and its great developer tooling and fast-growing ecosystem. That's great! You're already plotting to build your company's next Big Thing on this new technology platform.

One of the biggest barriers to entry to launching a separate application platform is the work it takes to access and authorize users. Your current tech stack is based on Rails - and all session management and user authentication are on that platform.

You're hesitant to rewrite the whole stack from the ground up. Your stack may also not be at the scale in which you have a separate identity authentication or authorization API.

Fortunately for you, somebody's written a great Phoenix plug to share sessions between Rails and Phoenix. If you pull this off right, you'll be able to spin up your Phoenix app with new feature capabilities, all while letting Rails handle user authentication and session management.

### Before we begin

In this scenario, you want to build out a new, high-performant API in Phoenix that is consumed by your frontend single-page application, whose sessions are hosted on Rails. We'll call the Rails app `rails_app` and your new Phoenix app `phoenix_app`.

In the examples that follow, I'll be using the latest versions of each framework at the time of writing, Rails 4.2 and Phoenix 1.2.

We are going to take [Chris Constantin](https://github.com/cconstantin)'s excellent [`PlugRailsCookieSessionStore`](https://github.com/cconstantin/plug_rails_cookie_session_store) plug and integrate it into our Phoenix project.

### Our approach

Our approach will be to configure the two apps with the same data to store and fetch session data accordingly. These will require the identical configuration of cookie domains, encryption and signing salts, and security tokens. Additionally, each app will use a different subdomain. The Rails app will be deployed at the `www.myapp.com` subdomain. The Phoenix app will be deployed at the `api.myapp.com` subdomain. Let's get started!

### Configure the plug for Phoenix

In your `mix.exs` file, add the plug dependency:

```elixir
# mix.exs
defmodule PhoenixApp
  defp deps do
    # snip
    {:plug_rails_cookie_session_store, "~> 0.1"},
    # snip
  end
```

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
    domain: ".#{System.get_env("DOMAIN")}",
    signing_salt: System.get_env("SESSION_ENCRYPTED_SIGNED_COOKIE_SALT"),
    encryption_salt: System.get_env("SESSION_ENCRYPTED_COOKIE_SALT"),
    key_iterations: 1000,
    key_length: 64,
    key_digest: :sha,
    serializer: Poison
end
```

#### A quick primer on session cookies

What did we just configure here?

Our session data is stored on the client in a secure, encrypted, validated cookie. We won't cover the basics of cookies here, but [you can read more about them](http://www.justinweiss.com/articles/how-rails-sessions-work/).

The `domain` configuration key specifies the matching rules on the hostname that this cookie will be valid for. We set a `DOMAIN` environment variable with the value
`myapp.com`. The goal is for these two apps to be able to be deployed at any subdomain that ends in `myapp.com`, and still be able to share the cookie.

The `secure` flag configures the app to send a secure cookie, which only is served over SSL HTTPS connections. It is highly recommended for your site; if you haven't upgraded to SSL, you should do so now!

Our cookies are signed such that their origins are guaranteed to have been computed from our app(s). This is done for free with Rails (and Phoenix's) session libraries. The signature is derived from the `secret_key_base` and `signing_salt`.

The `encrypt` flag encrypts the contents of the cookie's value with an encryption key derived from `secret_key_base` and `encryption_salt`. This should always be set to `true`.

`key_iterations`, `key_length` and `key_digest` are configurations that dictate how the signing and encryption keys are derived. These are [configured to match Rails' defaults](https://github.com/rails/rails/blob/4-2-stable/railties/lib/rails/application.rb) (see also: [defaults](https://github.com/rails/rails/blob/4-2-stable/activesupport/lib/active_support/key_generator.rb)). Unless your Rails app has custom configurations for these values, you should leave them be.

Finally, the `Poison` serializer is the JSON encoder that stores and decodes session data.

### Configure Rails accordingly

Now, we turn our attention to Rails. Keep in mind that this approach only works with Rails cookie-based sessions, so if your session storage options are based on using database lookups or with a custom solution, you're out of luck in this article.

#### Configure the cookie store

```ruby
# config/initializer/session_store.rb

# Use cookie session storage in JSON format. Here, we scope the cookie to the root domain.
Rails.application.config.session_store :cookie_store, key: '_rails_app_session', domain: ".#{ENV['DOMAIN']}"
Rails.application.config.action_dispatch.cookies_serializer = :json

# These salts are optional, but it doesn't hurt to explicitly configure them the same between the two apps.
Rails.application.config.action_dispatch.encrypted_cookie_salt = ENV['SESSION_ENCRYPTED_COOKIE_SALT']
Rails.application.config.action_dispatch.encrypted_signed_cookie_salt = ENV['SESSION_ENCRYPTED_SIGNED_COOKIE_SALT']
```

The same configuration variables apply here. Note that if you are missing a `SESSION_ENCRYPTED_COOKIE_SALT` and `SESSION_ENCRYPTED_SIGNED_COOKIE_SALT`, you may generate a pair with any random values. (Side discussion: [some speculate](http://nipperlabs.com/rails-secretkeybase) that the `SECRET_KEY_BASE` is sufficiently long enough to not require a salt, and hence why Rails does not require you to supply one by default. In our example, we choose to supply them anyways to be explicit.) In any case, the most important thing is that the salts match the salt values provided to the Phoenix app.

### Configure both apps to read from the new environment variables

Be sure your development and production versions of your app are configured with identical values for `DOMAIN`, `SESSION_ENCRYPTED_COOKIE_SALT` and `SESSION_ENCRYPTED_SIGNED_COOKIE_SALT`.

### Change your Phoenix endpoint(s) to verify sessions based on session data.

Now when the Phoenix app receives incoming requests, it can simply look up user session data in the session cookie to determine whether the user is logged in, and who that user is.

In this example, our Rails app implements user auth with Devise and Warden. We know that Warden stores the user ID and a segment of the password hash in the `warden.user.user.key` session variable.

```elixir
defmodule PhoenixApp.ApiController do
  use PhoenixApp.Web, :controller

  def index(conn, _params) do
    IO.inspect get_session(conn, "warden.user.user.key")
    render conn, "index.html"
  end

  plug :verify_session

  defp verify_session(conn, _) do
    user_id = conn |> get_session("warden.user.user.key")

    case user_id do
			nil -> conn |> send_resp(401, "Unauthorized") |> halt
      _ -> conn
    end
  end
end
```

A very naive plug implementation simply renders a 401 if the session key is not found in the session, otherwise it allows the request through.

Further implementation details are left up to you - you may want to proceed with a more robust JWT token serialization scheme where the contents of the user session are serialized into JWT format, where you may continue to provide authorization claims and privileges, or another custom format of your choosing.

The point is that now your Phoenix application has a handle on the user, understands that the Rails app has authenticated it, and is responsible for determining what to do with the user.

### Heroku deployment gotchas

If you are deploying this to Heroku with the popular [Heroku Elixir buildpack](git@github.com:HashNuke/heroku-buildpack-elixir.git), please be aware that adding or changing environment variables that are required at build time require that the new environment variables outlined here are added to your `elixir_buildpack.config` file in your repository.

```elixir
# elixir_buildpack.config
config_vars_to_export=(SECRET_KEY_BASE SESSION_ENCRYPTED_COOKIE_SALT SESSION_ENCRYPTED_SIGNED_COOKIE_SALT DOMAIN)
```

### Caveats and considerations

#### CSRF incompatibilites

At the time of this writing, Phoenix and Rails overwrite each others' CSRF tokens with incompatible schemes. This means that you may not be able to cross-write between the two apps with CSRF protection turned on. Our current approach will work best with a read-only API, at the moment.

#### Session coupling as an antipattern

Even though this scheme may work in the short run, coupling our apps at this level in the long run will result in headaches as the apps are coupled to intricate session implementation details. Consider developing and migrating to a centralized single-sign on OAuth system where all services pass a token to be validated by a single authentication API. Also consider implementing a JWT-based token implementation, in which all session and authorization claims are stored in the token itself, and encrypted in the client and server. Each of these approaches is not without overhead and complexity.

### Conclusion

That's it! I hope I've illustrated a quick and easy way to get a working Phoenix app sharing sessions with Rails app(s), should you decide to prototype one in your existing system. I've also pushed up a [sample app if you want to cross-reference the code](). Good luck!
