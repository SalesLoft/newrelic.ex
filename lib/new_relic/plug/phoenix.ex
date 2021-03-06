defmodule NewRelic.Plug.Phoenix do
  @moduledoc """
  A plug that instruments Phoenix controllers and records their response times in New Relic.

  Inside an instrumented controller's actions, `conn` can be used for further instrumentation with
  `NewRelic.Plug.Instrumentation` and `NewRelic.Plug.Repo`.

  ```
  defmodule MyApp.UsersController do
    use Phoenix.Controller
    plug NewRelic.Plug.Phoenix

    def index(conn, _params) do
      # `conn` is setup for instrumentation
    end
  end
  ```
  """

  @behaviour Elixir.Plug

  def init(opts) do
    opts
  end

  def call(conn, nil), do: call(conn, [])

  def call(conn, config) when is_list(config) do
    if NewRelic.configured? do
      name_fn = Keyword.get(config, :transaction_name_fn, &generate_transaction_name/1)
      transaction_name = name_fn.(conn)
      transaction = NewRelic.Transaction.start(transaction_name)
      NewRelic.TransactionStore.set(transaction)

      conn
      |> Plug.Conn.put_private(:new_relixir_transaction, transaction)
      |> Plug.Conn.register_before_send(fn conn ->
        NewRelic.Transaction.finish(Map.get(conn.private, :new_relixir_transaction))

        conn
      end)
    else
      conn
    end
  end

  def generate_transaction_name(conn) do
    module = conn |> Phoenix.Controller.controller_module |> Module.split |> List.last
    action = conn |> Phoenix.Controller.action_name |> Atom.to_string
    "#{module}##{action}"
  end
end
