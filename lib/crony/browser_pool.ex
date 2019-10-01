defmodule Crony.BrowserPool do
  use Supervisor

  @pool_name __MODULE__.Pool
  @supervisor __MODULE__

  def browser_worker_spec() do
    [
      name: {:local, @pool_name},
      worker_module: Crony.BrowserPool.Browser,
      size: 10,
      max_overflow: 0,
      strategy: :fifo
    ]
  end

  def start_link(opts) do
    Supervisor.start_link(@supervisor, :ok, opts)
  end

  def init(_args) do
    import Supervisor.Spec

    children = [
      # supervisor(Crony.BrowserPool.PortPool.Pool, Crony.BrowserPool.PortPool.pool_spec()),
      :poolboy.child_spec(@pool_name, browser_worker_spec())
    ]

    opts = [strategy: :rest_for_one, name: @supervisor]

    supervise(children, opts)
  end
end
