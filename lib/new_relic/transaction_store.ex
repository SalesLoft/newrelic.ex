defmodule NewRelic.TransactionStore do
  @transaction_key NewRelic.Transaction

  def set(transaction = %NewRelic.Transaction{}) do
    Process.put(@transaction_key, transaction)
  end

  def get() do
    Process.get(@transaction_key)
  end
end
