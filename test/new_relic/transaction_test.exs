defmodule NewRelic.TransactionTest do
  use ExUnit.Case, async: false
  import TestHelpers.Assertions

  alias NewRelic.Transaction

  @name "Test Transaction"

  # finish

  test "finish records elapsed time with correct key" do
    transaction = Transaction.start(@name)
    Transaction.finish(transaction)

    assert_contains(get_metric_keys(), {@name, :total})
  end

  test "finish clears out process transaction" do
    transaction = Transaction.start(@name)
    NewRelic.TransactionStore.set(transaction)
    Transaction.finish(transaction)
    assert NewRelic.TransactionStore.get() == nil
  end

  test "finish records accurate elapsed time" do
    {_, elapsed_time} = :timer.tc(fn() ->
      transaction = Transaction.start(@name)
      :ok = :timer.sleep(42)
      Transaction.finish(transaction)
    end)

    [recorded_time] = get_metric_by_key({@name, :total})
    assert_between(recorded_time, 42000, elapsed_time)
  end

  # record_db

  @model "SomeModel"
  @action "get"
  @elapsed 42

  test "record_db records query time with correct key when given model and action tuple" do
    transaction = Transaction.start(@name)
    Transaction.record_db(transaction, {@model, @action}, @elapsed)

    assert_contains(get_metric_keys(), {@name, {:db, "#{@model}.#{@action}"}})
  end

  test "record_db records accurate query time when given model and action tuple" do
    transaction = Transaction.start(@name)
    Transaction.record_db(transaction, {@model, @action}, @elapsed)

    [recorded_time] = get_metric_by_key({@name, {:db, "#{@model}.#{@action}"}})

    assert recorded_time == @elapsed
  end

  @query "FooBar"

  test "record_db records query time with correct key when given a string" do
    transaction = Transaction.start(@name)
    Transaction.record_db(transaction, @query, @elapsed)

    assert_contains(get_metric_keys(), {@name, {:db, @query}})
  end

  test "record_db records accurate query time when given a string" do
    transaction = Transaction.start(@name)
    Transaction.record_db(transaction, @query, @elapsed)

    [recorded_time] = get_metric_by_key({@name, {:db, @query}})

    assert recorded_time == @elapsed
  end

  describe "record_fn" do
    test "records query time with correct key" do
      NewRelic.TransactionStore.set(Transaction.start(@name))

      assert Transaction.record_execution_time(fn ->
        Process.sleep(10)
        "result"
      end, Test.Module, "method") == "result"

      [recorded_time] = get_metric_by_key({@name, {Test.Module, "method"}})

      assert_in_delta(recorded_time, 10 * 1000, 2000)
    end
  end

  describe "record_custom_transaction" do
    test "records the custom transaction" do
      assert Transaction.record_custom_transaction(fn ->
        %Transaction{name: "A Test"} = NewRelic.TransactionStore.get()
        "response"
      end, "A Test") == "response"

      [_start, _stop, %{{"A Test", :total} => [_time]}, %{}] = NewRelic.Collector.poll()
    end

    test "the custom transaction can be changed in flight" do
      assert Transaction.record_custom_transaction(fn ->
        transaction = %Transaction{name: "A Test"} = NewRelic.TransactionStore.get()
        transaction |> NewRelic.Transaction.update_name("change") |> NewRelic.TransactionStore.set()
        "response"
      end, "A Test") == "response"

      [_start, _stop, %{{"change", :total} => [_time]}, %{}] = NewRelic.Collector.poll()
    end
  end
end
