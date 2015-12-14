defmodule SSDBPoolTest do
  use ExUnit.Case

  @host "127.0.0.1"
  @port 6380

  setup_all do
    {:ok, _} = SSDBPool.start_link(
      @host,
      @port,
      5,    # pool_size
      nil  # password
    )

    :ok
  end

  test "query ok" do
    result = SSDBPool.query :ssdb_pool, ["hget", "test_pool_get", "unfound"]
    assert ["not_found"] == result
  end

end