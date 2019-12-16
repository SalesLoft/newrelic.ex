defmodule NewRelic.AgentTest do
  use ExUnit.Case, async: false
  alias NewRelic.Agent

  setup do
    assert Application.get_env(:new_relic, :application_name) == "Test"

    on_exit(fn ->
      Application.put_env(:new_relic, :application_name, "Test")
    end)
  end

  describe "app_name/0" do
    test "returns a list with a string if not separated" do
      assert Agent.app_name() == ["Test"]
    end

    test "returns a list with a nil if env var is nil" do
      Application.put_env(:new_relic, :application_name, nil)
      assert Agent.app_name() == [nil]
    end

    test "returns a list with multiple values if semi-colon separated" do
      Application.put_env(:new_relic, :application_name, "app-name-1;app-name-2")
      assert Agent.app_name() == ["app-name-1", "app-name-2"]
    end
  end
end
