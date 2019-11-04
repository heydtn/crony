defmodule Crony do
  defdelegate run_session(fun), to: Crony.SessionPool
end
