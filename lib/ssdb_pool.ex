require Lager

defmodule SSDBPoolInfo do
  defstruct host: '127.0.0.1', port: 8888, password: nil,
            pool_size: 5, querys: :queue.new, conns: :queue.new
end

defmodule SSDBPool do
  use GenServer

  @reconnect_delay_ms 3000

  def start_link(host, port, pool_size, password \\ nil) do
    GenServer.start_link(__MODULE__, {host, port, pool_size, password}, [name: :ssdb_pool])
  end

  def init({host, port, pool_size, password}) do
    :erlang.process_flag(:trap_exit, true)
    state = %SSDBPoolInfo{
      host: host, port: port, password: password, pool_size: pool_size
    }
    {:ok, state, 0}
  end

  def query(pid, cmd) do
    GenServer.call pid, {:query_push, cmd}
  end

  def handle_info(:timeout, state) do
    connect(state, state.pool_size)
    {:noreply, state}
  end

  def handle_info({:query_pull, conn}, state) do
    state_new = case :queue.member conn, state.conns do
      true -> state
      false ->
        conns = :queue.in conn, state.conns
        %{state | conns: conns}
    end

    state_new = clean_query state_new
    {:noreply, state_new}
  end

  def handle_call({:query_push, query}, from, state) do
    querys = :queue.in {from, query}, state.querys
    state_new = %{state | querys: querys} |> clean_query
    {:noreply, state_new}
  end

  def clean_query(%{conns: {[],[]}}=state), do: state
  def clean_query(%{querys: {[],[]}}=state), do: state
  def clean_query(state) do
    {{:value, conn}, conns} = :queue.out state.conns
    {{:value, query}, querys} = :queue.out state.querys

    send conn, {:query, query}

    state_new = %{state | conns: conns, querys: querys}
    clean_query(state_new)
  end

  def handle_info({:EXIT, conn, reason}, %SSDBPoolInfo{}=state) do
    Lager.error "ssdb conn(~p) EXIT, reason: ~p", [conn, reason]
    :erlang.send_after(@reconnect_delay_ms, self, :connect)
    {:noreply, state}
  end

  def handle_info(:connect, state) do
    connect state, 1
    {:noreply, state}
  end

  def connect(state, 0), do: :ok
  def connect(state, num) when num > 0 do
    case SSDBConn.start_link(state.host, state.port) do
      {:ok, pid} ->
        Lager.info "ssdb connect success"
      error ->
        Lager.error "ssdb connect error: ~p", [error]
    end
    connect(state, num - 1)
  end
end