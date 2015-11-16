defmodule SSDBSup do
  use Supervisor

  def start_link(opts \\ [name: :ssdb_sup]) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  def init(_conf) do

    host = Application.get_env(:ssdb, :host, "127.0.0.1")
    port = Application.get_env(:ssdb, :port, 6380)
    pool_size = Application.get_env(:ssdb, :pool_size, 5)
    password = Application.get_env(:ssdb, :password, nil)

    pool_args = [host, port, pool_size, password]
    children = [
      worker(SSDBPool, pool_args)
    ]

    supervise(children, strategy: :one_for_one)
  end
end