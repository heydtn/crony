defmodule Crony.BrowserPool.Browser do
  use GenServer

  alias Crony.BrowserPool.PortPool
  alias Crony.BrowserPool.Browser.Chrome

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(_opts) do
    {:ok, nil, {:continue, :initialize_browser}}
  end

  def handle_continue(:initialize_browser, _state) do
    {:ok, port} = GenServer.call(PortPool.Pool, :lease_port)
    {:ok, instance} = Chrome.start_link(chrome_port: port)

    Chrome.ready(instance)

    {:noreply, instance}
  end

  def handle_call(:get_instance, instance) do
    {:reply, instance, instance}
  end

  @doc """
  Lists page sessions currently open to the chrome instance.
  """
  def list_pages(browser) do
    instance = GenServer.call(browser, :get_instance)

    Chrome.list_pages(instance)
  end

  @doc """
  Creates a new chrome page (tab) within the chrome instance.
  """
  def new_page(browser) do
    instance = GenServer.call(browser, :get_instance)

    Chrome.new_page(instance)
  end

  @doc """
  Closes the page in the chrome instance.
  """
  def close_page(browser, page) do
    instance = GenServer.call(browser, :get_instance)

    Chrome.close_page(instance, page)
  end

  @doc """
  Closes all open pages in the chrome instance.
  """
  def close_all_pages(browser) do
    instance = GenServer.call(browser, :get_instance)

    Chrome.close_all_pages(instance)
  end
end
