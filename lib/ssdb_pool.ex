require Lager

defmodule SSDBPoolInfo do
  defstruct host: '127.0.0.1', port: 8888, password: nil,
            pool_size: 5, has_reconnected: false, conn_pools: :queue.new
end

defmodule SSDBPool do
  use GenServer

  @reconnect_delay_ms 3000

  def start_link(host, port, pool_size, password \\ nil) do
    GenServer.start_link(__MODULE__, {host, port, pool_size, password}, [name: :ssdb_pool])
  end

  def init({host, port, pool_size, password}) do
    :erlang.process_flag(:trap_exit, true)
    conn_pools = start_pools host, port, password, pool_size
    state = %SSDBPoolInfo{
      host: host, port: port, password: password, pool_size: pool_size,
      conn_pools: conn_pools
    }
    {:ok, state}
  end

  def query(pid, cmd) do
    GenServer.call pid, {:ssdb_query, cmd}
  end

  def handle_call({:ssdb_query, cmd}, from, state) do
    case get_conn(state) do
      {:ok, conn, new_state} ->
        send conn, {:ssdb_query, from, cmd}
        {:noreply, new_state}
      :error ->
        {:reply, :conn_pools_empty, state}
    end
  end

  def handle_info({:EXIT, conn, reason}, %SSDBPoolInfo{conn_pools: conn_pools, has_reconnected: has_reconnected}=state) do
    Lager.error "ssdb conn(~p) EXIT, reason: ~p", [conn, reason]
    conn_pools = (fn(c)-> c != conn end) |> :queue.filter conn_pools

    unless has_reconnected do
      :erlang.send_after(@reconnect_delay_ms, self, :reconnect)
      has_reconnected = true
    end

    state = %{state | conn_pools: conn_pools, has_reconnected: has_reconnected}

    {:noreply, state}
  end

  def handle_info(:reconnect, %SSDBPoolInfo{conn_pools: conn_pools, pool_size: pool_size}=state) do
    Lager.info "ssdb reconnecting.."
    reconnect_size = pool_size - :queue.len(conn_pools)
    if reconnect_size > 0 do
      conn_pools = start_pools(state.host, state.port, state.password, reconnect_size, conn_pools)
    end

    state = %{state | conn_pools: conn_pools, has_reconnected: false}

    {:noreply, state}
  end

  def get_conn(%SSDBPoolInfo{conn_pools: {[], []}}=state), do: :error
  def get_conn(%SSDBPoolInfo{conn_pools: conn_pools}=state) do
    {{:value, conn}, conn_pools} = :queue.out conn_pools
    conn_pools = :queue.in conn, conn_pools
    state = %{state | conn_pools: conn_pools}
    {:ok, conn, state}
  end

  def start_pools(host, port, password, pool_size, pools \\ :queue.new) do
    (1..pool_size) |> Enum.reduce pools, fn(_, pools_new)->
      case SSDBConn.start_link(host, port) do
        {:ok, pid} ->
          case password do
            nil -> :ok
            _ -> ["ok", "1"] = GenServer.call(pid, {:ssdb_query, [:auth, password]})
          end
          :queue.in(pid, pools_new)
        error ->
          pools_new
      end
    end
  end
end