defmodule SSDBPoolTest do
  use ExUnit.Case

  @host "127.0.0.1"
  @port 6380

  setup_all do
    {:ok, _} = SSDBPool.start_link(
      @host,
      @port,
      5,    # pool_size
      nil,  # password
      true  # reconnect
    )

    :ok
  end

  test "query ok" do
    result = SSDBPool.query :ssdb_pool, ["hget", "test_pool_get", "unfound"]
    assert ["not_found"] == result
  end


  test "start_pools new" do
    pools = SSDBPool.start_pools(@host, @port, nil, 3)
    result = pools |> :queue.to_list |> Enum.map fn(pid)-> is_pid(pid) end
    assert [true, true, true] == result
  end

  test "start_pools with exist" do
    pools = SSDBPool.start_pools(@host, @port, nil, 3)
    pools = SSDBPool.start_pools(@host, @port, nil, 1, pools)
    result = pools |> :queue.to_list |> Enum.map fn(pid)-> is_pid(pid) end
    assert [true, true, true, true] == result
  end

  test "get_conn empty error" do
    assert :error == SSDBPool.get_conn %SSDBPoolInfo{}
  end

  test "get_conn fifo" do
    pools = :queue.from_list [1,2,3]
    info = %SSDBPoolInfo{conn_pools: pools}

    {:ok, c, _} = SSDBPool.get_conn(info)
    assert c == 1
  end
end