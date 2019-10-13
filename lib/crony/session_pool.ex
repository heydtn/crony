defmodule Crony.SessionPool do
  use Brex.Result

  alias Crony.{BrowserPool, BrowserPool.Browser}

  def session do
    BrowserPool.transaction(fn browser ->
      Browser.new_page(browser)
      |> fmap(fn page -> {browser, page} end)
    end)
  end
end
