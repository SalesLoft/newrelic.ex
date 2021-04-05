# Deprecated

Use the [official library](https://github.com/newrelic/elixir_agent) now instead of this one.

# NewRelic agent for Elixir

[![Build Status](https://travis-ci.org/romul/newrelic.ex.svg?branch=master)](https://travis-ci.org/romul/newrelic.ex)

Instrument your Phoenix applications with New Relic.

It currently supports instrumenting Phoenix controllers and Ecto repositories to record
response times for web transactions and database queries.

Based on [newrelic-erlang](https://github.com/wooga/newrelic-erlang) and [new-relixir](https://github.com/TheRealReal/new-relixir)


## Why yet another?

1. `newrelic-erlang` & `new-relixir` look abandoned, so the main goal is to create a maintainable integration with NewRelic open to pull requests.
2. `newrelic-erlang` has a performance issue related to `statman` usage. Look at a real-world example of `new-relixir` usage (the project handles about 25 rps):

![CPU load](https://api.monosnap.com/rpc/file/download?id=WhmimUZqDkvFkbznpaD6OmqG1tbP1G)
![Memory usage](https://api.monosnap.com/rpc/file/download?id=fI3kVrEyyebqIiIhs38yLZUQaQJkkc)

The `new_relic` isn't suffer from such the leaks.

## Usage

The following instructions show how to add instrumentation with New Relic to a hypothetical
Phoenix application named `MyApp`.

1.  Add `new_relic` to your list of dependencies and start-up applications in `mix.exs`:

    ```elixir
    # mix.exs

    defmodule MyApp.Mixfile do
      use Mix.Project

      # ...

      def application do
        [mod: {MyApp, []},
         applications: [:new_relic]]
      end

      defp deps do
        [{:new_relic, "~> 0.1.2"}]
      end
    end
    ```

2.  Add your New Relic application name and license key to `config/config.exs`. You may wish to use
    environment variables to keep production, staging, and development environments separate:

    ```elixir
    # config/config.exs

    config :new_relic,
      application_name: System.get_env("NEWRELIC_APP_NAME"),
      license_key: System.get_env("NEWRELIC_LICENSE_KEY"),
      poll_interval: 60_000 # push data to NewRelic once per 1 minute
    ```


3.  Define a module to wrap your repository's methods with New Relic instrumentation:

    ```elixir
    # lib/my_app/repo.ex

    defmodule MyApp.Repo do
      use Ecto.Repo, otp_app: :my_app

      defmodule NewRelic do
        use Elixir.NewRelic.Plug.Repo, repo: MyApp.Repo
      end
    end
    ```

    Now `MyApp.Repo.NewRelic` can be used as a substitute for `MyApp.Repo`. If a `Plug.Conn` is
    provided as the `:conn` option to any of the wrapper's methods, it will instrument the response
    time for that call. Otherwise, the repository will behave the same as the repository that it
    wraps.

4.  For any Phoenix controller that you want to instrument, add `NewRelic.Plug.Phoenix` and
    replace existing aliases to your application's repository with an alias to your New Relic
    repository wrapper. If instrumenting all controllers, update `web/web.ex`:

    ```elixir
    # web/web.ex

    defmodule MyApp.Web do
      def controller do
        quote do
          # ...
          plug NewRelic.Plug.Phoenix
          alias MyApp.Repo.NewRelic, as: Repo # Replaces `alias MyApp.Repo`
        end
      end
    end
    ```

    It is also possible to specify a custom transaction name function to provide your
    transaction name, falling back to the default naming scheme as needed:

    ```elixir
    defmodule MyApp.Web do
      def controller do
        quote do
          # ...
          plug(NewRelic.Plug.Phoenix, transaction_name_fn: &MyApp.Web.get_front_transaction_name/1)
        end
      end

      def get_front_transaction_name(%{assigns: %{route: route_name}}) do
        to_string(route_name)
      end

      # Fallback to the default Plug transaction name
      def get_front_transaction_name(conn), do: NewRelic.Plug.Phoenix.generate_transaction_name(conn)
    end
    ```

5.  Your db calls will automatically be captured inside of any New Relic transaction. However,
    this only works if the database work is done in the same process as the transaction. This
    is most likely acceptable, but you may need to instrument database calls across the process
    boundary. In that case:

    Update your cross-boundary code to pass `conn` as an option to your New Relic repo wrapper:

    ```elixir
    # web/controllers/users.ex

    defmodule MyApp.UserController do
      use MyApp.Web, :controller

      def index(conn, _params) do
        users = UserProcess.all(User, conn: conn) # UserProcess is a separate process that fetches Users
        # ...
      end
    end
    ```

### Instrumenting Arbitrary Transactions

It is possible to add New Relic transaction monitoring to any part of your application.
This can be useful to place inside of background workers, channels, or message processors.
In order to do so, wrap your code inside of a function and pass it to
`NewRelic.Transaction.record_custom_transaction`:

```elixir
NewRelic.Transaction.record_custom_transaction(
  fn ->
    my_custom_code
  end,
  "MyCustom.TransactionName"
)
```

### Instrumenting Custom Repo Methods

If you've defined custom methods on your repository, you will need to define them on your wrapper
module as well. In the wrapper module, simply call your repository's original method inside a
closure that you pass to `instrument_db`:

```elixir
# lib/my_app/repo.ex

defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app

  def custom_method(queryable, opts \\ []) do
    # ...
  end

  defmodule NewRelic do
    use NewRelic.Plug.Repo, repo: MyApp.Repo

    def custom_method(queryable, opts \\ []) do
      instrument_db(:custom_method, queryable, opts, fn() ->
        MyApp.Repo.custom_method(queryable, opts)
      end)
    end
  end
end
```

When using the wrapper module's `custom_method`, the time it takes to call
`MyApp.Repo.custom_method/2` will be recorded to New Relic.



Distributed under the [MIT License](LICENSE).
