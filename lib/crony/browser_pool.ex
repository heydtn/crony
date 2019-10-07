defmodule Crony.BrowserPool do
  use Supervisor

  require Logger

  @supervisor __MODULE__
  @pool_name __MODULE__.Pool
  @browser_worker __MODULE__.Browser

  @port_pool Crony.BrowserPool.PortPool
  @port_pool_name Crony.BrowserPool.PortPool.Pool

  @spec browser_pool_range :: Range.t()
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

  @spec browser_worker_spec(Range.t()) :: [{atom(), term()}]
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

  @spec port_pool_args(Range.t()) :: [Range.t() | any]
  def port_pool_args(pool_range) do
    [
      pool_range,
      [name: @port_pool_name]
    ]
  end

  def start_link(opts) do
    default_opts = [name: __MODULE__]

    final_opts = Keyword.merge(default_opts, opts)

    Supervisor.start_link(@supervisor, :ok, final_opts)
  end

  def init(_args) do
    import Supervisor.Spec

    pool_range = browser_pool_range()

    children = [
      worker(@port_pool, port_pool_args(pool_range), restart: :permanent),
      :poolboy.child_spec(@pool_name, browser_worker_spec(pool_range))
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
