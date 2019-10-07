defmodule Crony.BrowserPool.Browser do
  use GenServer

  alias Crony.BrowserPool.PortPool

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(_opts) do
    {:ok, port} = GenServer.call(PortPool.Pool, :lease_port)

    IO.puts("Initiating browser with port #{port}")

    {:ok, port}
  end
end
