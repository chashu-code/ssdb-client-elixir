defmodule SSDBConnTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, conn} = SSDBConn.start_link("127.0.0.1", 6380)
    query = fn(cmd) ->
      send conn, {:ssdb_query, {self, :test}, cmd}
    end

    on_exit fn ->
      [""] |> query.()
    end

    {:ok, %{conn: conn, query: query}}
  end


  test "get unfound", cxt do
    ["get", "test_get_unfound"] |> cxt.query.()
    assert_receive {:test, ["not_found"]}
  end

  test "get found", cxt do
    ["set", "test_get", "hello"]  |> cxt.query.()
    ["get", "test_get"] |> cxt.query.()

    assert_receive {:test, ["ok", "hello"]}
  end

  test "hget noraml", cxt do
    ["hset", "test_hget", "abc", 1111] |> cxt.query.()
    ["hget", "test_hget", "abc"] |> cxt.query.()

    assert_receive {:test, ["ok", "1111"]}
  end

  test "hget bigdata", cxt do
    data = "123\n456\n\n78910" |> :binary.copy(2000)

    ["hset", "test_hget", "big", data] |> cxt.query.()
    ["hget", "test_hget", "big"] |> cxt.query.()

    assert_receive {:test, ["ok", ^data]}
  end

end