defmodule SSDBConnTest do
  use ExUnit.Case

  setup do
    Process.register(self, :ssdb_pool)

    {:ok, conn} = SSDBConn.start_link("127.0.0.1", 6380)
    query = fn(cmd) ->
      SSDBConn.query conn, cmd
    end

    on_exit fn ->

    end

    {:ok, %{conn: conn, query: query}}
  end


  test "get unfound", cxt do
    ["not_found"] = ["get", "test_get_unfound"] |> cxt.query.()
    # assert
  end

  test "get found", cxt do
    ["ok", _] = ["set", "test_get", "hello"]  |> cxt.query.()
    ["ok", "hello"] = ["get", "test_get"] |> cxt.query.()
  end

  test "hget noraml", cxt do
    ["ok", _] = ["hset", "test_hget", "abc", 1111] |> cxt.query.()
    ["ok", "1111"] = ["hget", "test_hget", "abc"] |> cxt.query.()
  end

  test "hget bigdata", cxt do
    data = "123\n456\n\n78910" |> :binary.copy(2000)

    ["ok", _] = ["hset", "test_hget", "big", data] |> cxt.query.()
    ["ok", ^data] = ["hget", "test_hget", "big"] |> cxt.query.()
  end

end