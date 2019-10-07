defmodule Crony.Browser.PortPool do
  use GenServer
  use Brex.Result

  require Logger

  alias Crony.Browser.PortPool.State

  def start_link(range, opts) do
    GenServer.start_link(__MODULE__, range, opts)
  end

  @spec init(Range.t()) :: {:ok, State.t()}
  def init(range) do
    {:ok, State.init(range)}
  end

  def handle_call(:lease_port, {caller, call_ref}, state_current) do
    State.lease_to(state_current, caller, call_ref)
    |> case do
      {:ok, {port, state_new}} ->
        {:reply, {:ok, port}, state_new}

      {:error, _} = error ->
        {:reply, error, state_current}
    end
  end

  def handle_call({:lease_port_for, receiver_pid}, _from, state_current)
      when not is_pid(receiver_pid) do
    {:reply, {:error, :badarg}, state_current}
  end

  def handle_call({:lease_port_for, receiver_pid}, {_, call_ref}, state_current)
      when is_pid(receiver_pid) do
    State.lease_to(state_current, receiver_pid, call_ref)
    |> case do
      {:ok, {port, state_new}} ->
        {:reply, {:ok, port}, state_new}

      {:error, _} = error ->
        {:reply, error, state_current}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:release_port, leased_port}, _from, state_current)
      when not is_integer(leased_port) or not (leased_port >= 0 and leased_port <= 65535) do
    {:reply, {:error, :badarg}, state_current}
  end

  def handle_call({:release_port, leased_port}, _from, state_current) do
    State.release_by_port(state_current, leased_port)
    |> case do
      {:ok, state_new} ->
        {:reply, :ok, state_new}

      {:error, _} = result_err ->
        {:reply, result_err, state_current}
    end
  end

  def handle_call(_, _from, state) do
    {:reply, {:error, :invalid_call}, state}
  end

  def handle_info({:DOWN, ref, :process, _object, _reason}, state_current) do
    State.release_by_monitor(state_current, ref)
    |> case do
      {:ok, state_new} ->
        {:reply, :ok, state_new}

      {:error, _} = result_err ->
        Logger.warn("Unable to port and monitor for reference #{ref}: #{inspect(result_err)}")
        {:noreply, state_current}
    end
  end
end
