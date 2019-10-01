defmodule Crony.ChromeServer do
  @moduledoc """
  `DynamicSupervisor` for `Crony.ChromeServer`
  """

  @supervisor __MODULE__
  @worker Crony.ChromeServer.Connection

  def child_spec() do
    {DynamicSupervisor, name: @supervisor, strategy: :one_for_one}
  end

  def start_child(args) do
    DynamicSupervisor.start_child(@supervisor, @worker.child_spec(args))
  end

  def which_children() do
    DynamicSupervisor.which_children(@supervisor)
  end
end
