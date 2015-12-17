defmodule SSDB do
  use Application

  def start(_type, _args) do
    {:ok, _} = SSDBSup.start_link
  end

  def query(cmd, timeout \\ 5000) when is_list(cmd) do
    SSDBPool.query :ssdb_pool, cmd, timeout
  end
end
