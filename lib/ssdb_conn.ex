require Lager

defmodule SSDBConnInfo do
   defstruct socket: nil, step: 0, data: <<>>, size: 0, reply: [], from_list: []
end

defmodule SSDBConn do
  use GenServer

  @step_size 0
  @step_data 1
  @step_finish 2

  @tcp_options [:binary,{:active,true},{:packet,0},{:keepalive,true}]

  def start_link(host, port) do
    GenServer.start_link(__MODULE__, {host, port}, [])
  end


  def init({host, port}) do
    if is_binary(host), do: host = String.to_char_list host
    case :gen_tcp.connect(host, port, @tcp_options) do
      {:ok, socket} ->
        state = %SSDBConnInfo{
          socket: socket, step: @step_finish
        }
        {:ok, state}
      error ->
        {:stop, error}
    end
  end

  def handle_info({:tcp_closed, socket}, state) do
    Lager.error "ssdb tcp_closed."
    {:stop, :tcp_closed, state}
  end

  def handle_info({:tcp_error, socket, reason}, state) do
    Lager.error "ssdb tcp_error: ~p", [reason]
    {:stop, :tcp_closed, state}
  end

  def handle_info({:tcp, socket, data}, state) do
    case parse_recv(state, data) do
      %SSDBConnInfo{step: @step_finish, reply: reply, from_list: [{from, _} | from_list]}=new_state ->
        GenServer.reply from, reply
        new_state = %{new_state | from_list: from_list, reply: []} |> send_query
        {:noreply, new_state}
      %SSDBConnInfo{}=new_state ->
        {:noreply, new_state}
      :error ->
        {:stop, :packet_error, state}
    end
  end


  def handle_info({:ssdb_query, from, cmd}, state) do
    new_state = %{state | from_list: state.from_list ++ [{from, cmd}]}
                |> send_query
    {:noreply, new_state}
  end


  def parse_recv(%SSDBConnInfo{step: @step_size, data: data}=state, data_recv) do
    if byte_size(data_recv) > 0, do: data = data <> data_recv

    case :binary.match(data, "\n") do
      {pos, 1} ->
        size = data |> binary_part(0, pos) |> String.to_integer
        pos = pos + 1
        data_rest = data |> binary_part(pos, byte_size(data) - pos)
        state = %{state | data: data_rest, step: @step_data, size: size}
        parse_recv state, ""
      :nomatch ->
        %{state | data: data}
    end
  end

  def parse_recv(%SSDBConnInfo{step: @step_data, data: data, size: size, reply: reply}=state, data_recv) do
    if byte_size(data_recv) > 0, do: data = data <> data_recv

    size_recv = byte_size(data)

    if size_recv >= size + 2 do
      # recv \n\n or \n+"size"
      case data do
        <<msg :: bytes-size(size), "\n\n" :: bytes, data_rest :: bytes >> ->
          case data_rest do
            <<>> ->
              reply = :lists.reverse [msg | reply]
              state = %{state | step: @step_finish, size: 0, data: <<>>, reply: reply}
            _ ->
              Lager.error "ssdb conn parse recv error"
              :error
          end
        <<msg :: bytes-size(size), "\n" :: bytes, data_rest :: bytes >> ->
          reply = [msg | reply]
          state = %{state | step: @step_size, size: 0, data: data_rest, reply: reply}
          parse_recv state, ""
      end
    else
      %{state | data: data}
    end
  end

  def send_query(%SSDBConnInfo{ step: @step_finish,
                                socket: socket,
                                from_list: [{_from, cmd} | _]
                              }=state) do
    data = encode_cmd(cmd, "")
    :gen_tcp.send(socket, data)
    state = %{state | step: @step_size}
  end
  def send_query(%SSDBConnInfo{}=state), do: state

  def encode_cmd([], cmd), do: cmd <> "\n"
  def encode_cmd([h | t], cmd) do
    h = to_binary h
    size = byte_size h
    cmd = cmd <> to_binary(size) <> "\n" <> h <> "\n"
    encode_cmd(t, cmd)
  end


  def to_binary(msg) when is_binary(msg), do: msg
  def to_binary(msg) when is_atom(msg), do: Atom.to_string(msg)
  def to_binary(msg) when is_list(msg), do: List.to_string(msg)
  def to_binary(msg) when is_integer(msg), do: Integer.to_string(msg)
  def to_binary(msg) when is_float(msg), do: Float.to_string(msg)
  def to_binary(msg) when is_tuple(msg), do: Tuple.to_list(msg) |> to_binary
end