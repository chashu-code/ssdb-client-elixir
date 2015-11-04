defmodule SSDB do
  use Application

  def start(_type, _args) do
    {:ok, _} = SSDBSup.start_link
  end

  def query(cmd) when is_list(cmd) do
    SSDBPool.query :ssdb_pool, cmd
  end
end
