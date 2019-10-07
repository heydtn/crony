defmodule Crony.BrowserPool do
  use Supervisor

  require Logger

  @supervisor __MODULE__
  @pool_name __MODULE__.Pool
  @browser_worker __MODULE__.Browser

  def browser_pool_range() do
    try do
      port_range_start =
        Application.get_env(:crony, :chrome_remote_debug_port_from)
        |> String.to_integer()

      port_range_end =
        Application.get_env(:crony, :chrome_remote_debug_port_to)
        |> String.to_integer()

      port_range_start..port_range_end
    rescue
      ArgumentError ->
        Logger.error(
          "Invalid configuration for browserpool port range, defaulting to 9222 through 9228"
        )

        9222..9228
    end
  end

  def browser_worker_spec(pool_range) do
    start..finish = pool_range
    pool_size = finish - start + 1

    [
      name: {:local, @pool_name},
      worker_module: @browser_worker,
      size: pool_size,
      max_overflow: 0,
      strategy: :fifo
    ]
  end

  def port_pool_args(pool_range) do
    [
      pool_range,
      [name: Crony.BrowserPool.PortPool.Pool]
    ]
  end

  def start_link(opts) do
    Supervisor.start_link(@supervisor, :ok, opts)
  end

  def init(_args) do
    import Supervisor.Spec

    pool_range = browser_pool_range()

    children = [
      worker(
        Crony.BrowserPool.PortPool,
        port_pool_args(pool_range),
        restart: :permanent
      ),
      :poolboy.child_spec(@pool_name, browser_worker_spec(pool_range))
    ]

    opts = [strategy: :rest_for_one, name: @supervisor]

    supervise(children, opts)
  end
end
