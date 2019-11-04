defmodule Crony.SessionPool.Session do
  use GenServer

  use Brex.Result

  alias ChromeRemoteInterface.PageSession
  alias Crony.{BrowserPool, BrowserPool.Browser}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @spec init(any) :: {:ok, nil, {:continue, :initialize}}
  def init(_opts) do
    {:ok, nil, {:continue, :initialize}}
  end

  @spec handle_continue(:initialize | :new_session, any) ::
          {:noreply, any} | {:noreply, nil, {:continue, :initialize}}
  def handle_continue(:initialize, _state) do
    {:ok, session} =
      BrowserPool.transaction(fn browser ->
        Browser.new_page(browser)
        |> fmap(fn session -> {browser, session} end)
      end)

    {:noreply, session}
  end

  def handle_continue(:new_session, {browser, page}) do
    Browser.close_page(browser, page)

    {:noreply, nil, {:continue, :initialize}}
  end

  def handle_call({:run_with_session, fun}, _from, {_browser, page} = session) do
    session_url = page["webSocketDebuggerUrl"]
    {:ok, page_session} = PageSession.start_link(session_url)

    result =
      try do
        fun.(page_session)
      after
        PageSession.stop(page_session)
      end

    {:reply, result, session, {:continue, :new_session}}
  end

  def terminate(reason, nil) do
    reason
  end

  def terminate(reason, {browser, page}) do
    Browser.close_page(browser, page)

    reason
  end
end
