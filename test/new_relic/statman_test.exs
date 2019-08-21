defmodule NewRelic.StatmanTest do
  use ExUnit.Case, async: false

  describe "poll/0" do
    test "" do
      NewRelic.Collector.record_value({"FakeTransaction", :total}, 100_000)
      NewRelic.Collector.record_value({"FakeTransaction", :total}, 200_000)
      NewRelic.Collector.record_value({"FakeTransaction", {:db, "MyModel.all"}}, 100)
      NewRelic.Collector.record_value({"FakeTransaction", {:db, "MyModel.all"}}, 200)
      {metrics, errs, {start_at, end_at}} = NewRelic.Statman.poll()

      assert errs == []
      assert start_at < end_at
      assert metrics == [
        [%{name: "HttpDispatcher", scope: ""}, [2, 0.3, 0.3, 0, 0.2, 0.05]],
        [%{name: "Database/all", scope: ""}, [4, 0.0006, 0.0006, 0.0, 0.0002, 1.0e-7]],
        [%{name: "Errors/all", scope: ""}, [0, 0.0, 0.0, 0.0, 0.0, 0.0]],
        [%{name: "Errors/allWeb", scope: ""}, [0, 0.0, 0.0, 0.0, 0.0, 0.0]],
        [%{name: "Instance/Reporting", scope: ""}, [0, 0.0, 0.0, 0.0, 0.0, 0.0]],
        [
          %{name: "WebTransaction/Uri/FakeTransaction", scope: ""},
          [2, 0.3, 0.3, 0, 0.2, 0.05]
        ],
        [
          %{name: "Database/MyModel.all", scope: "WebTransaction/Uri/FakeTransaction"},
          [2, 0.0003, 0.0003, 0, 0.0002, 5.0e-8]
        ],
        [
          %{name: "Database/allWeb", scope: ""},
          [2, 0.0003, 0.0003, 0, 0.0002, 5.0e-8]
        ],
        [
          %{name: "Database/all", scope: ""},
          [2, 0.0003, 0.0003, 0, 0.0002, 5.0e-8]
        ],
      ]
    end
  end
end
