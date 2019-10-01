defmodule Crony.ChromeServer do
  @moduledoc """
  `DynamicSupervisor` for `Crony.ChromeServer`
  """

  use DynamicSupervisor

  @supervisor __MODULE__
  @worker Crony.ChromeServer.Connection

  def child_spec() do
    %{
      id: @supervisor,
      start: {@supervisor, :start_link, []},
      restart: :transient,
      shutdown: 5000,
      type: :supervisor
    }
  end

  def start_link() do
    DynamicSupervisor.start_link(@supervisor, :ok, name: @supervisor)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(args) do
    DynamicSupervisor.start_child(@supervisor, @worker.child_spec(args))
  end

  def which_children() do
    DynamicSupervisor.which_children(@supervisor)
  end
end
