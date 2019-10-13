defmodule Crony.SessionPool do
  use Supervisor
  use Brex.Result

  alias Crony.SessionPool.Session

  @supervisor __MODULE__
  @pool_name __MODULE__.Pool

  @session_timeout 99_999

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor
    }
  end

  def session_worker_spec() do
    [
      name: {:local, @pool_name},
      worker_module: Session,
      size: page_count_limit(),
      max_overflow: 0,
      strategy: :fifo
    ]
  end

  @spec page_count_limit :: any
  def page_count_limit() do
    Application.get_env(__MODULE__, :page_count_limit, 400)
  end

  def start_link(opts) do
    default_opts = [name: __MODULE__]

    final_opts = Keyword.merge(default_opts, opts)

    Supervisor.start_link(@supervisor, :ok, final_opts)
  end

  def init(_args) do
    children = [
      :poolboy.child_spec(
        @pool_name,
        session_worker_spec()
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def run_session(fun) do
    :poolboy.transaction(
      @pool_name,
      fn session ->
        GenServer.call(session, {:run_with_session, fun})
      end,
      @session_timeout
    )
  end
end
