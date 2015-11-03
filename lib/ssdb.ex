defmodule SSDB do
  use Application

  def start(_type, _args) do
    {:ok, _} = SSDBSup.start_link
  end
end
