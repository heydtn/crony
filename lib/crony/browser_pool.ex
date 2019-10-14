defmodule Crony.BrowserPool do
  use Supervisor
  use Brex.Result

  require Logger

  alias Crony.BrowserPool.PortPool
  alias Crony.BrowserPool.Browser

  @supervisor __MODULE__
  @pool_name __MODULE__.Pool

  @transaction_timeout 10_000

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor
    }
  end

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
      worker_module: Browser,
      size: pool_size,
      max_overflow: 0,
      strategy: :fifo
    ]
  end

  def transaction(fun) do
    :poolboy.transaction(
      @pool_name,
      fn pid ->
        fun.(pid)
      end,
      @transaction_timeout
    )
  end

  def start_link(opts) do
    default_opts = [name: __MODULE__]

    final_opts = Keyword.merge(default_opts, opts)

    Supervisor.start_link(@supervisor, :ok, final_opts)
  end

  def init(_args) do
    pool_range = browser_pool_range()

    children = [
      PortPool.child_spec(
        range: pool_range,
        name: PortPool.Pool
      ),
      :poolboy.child_spec(
        @pool_name,
        browser_worker_spec(pool_range)
      )
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
