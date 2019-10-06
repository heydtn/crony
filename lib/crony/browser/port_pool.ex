defmodule Crony.Browser.PortPool do
  use GenServer
  use Brex.Result

  require Logger

  alias Crony.DualMap

  defmodule InvalidState do
  end

  def start_link(range, opts) do
    GenServer.start_link(__MODULE__, range, opts)
  end

  def init(range) do
    ip_pool =
      range
      |> Enum.to_list()
      |> :queue.from_list()

    {:ok, %{ports: ip_pool, leases: %DualMap{}}}
  end

  def handle_call(
        :lease_port,
        from,
        %{ports: ports, leases: leases} = state_current
      ) do
    {result, ports_remaining} = :queue.out(ports)

    perform_lease = fn port ->
      state_updated_ports = %{state_current | ports: ports_remaining}

      lease_port_to(port, from, leases, state_updated_ports)
    end

    result
    |> queue_out_to_result()
    |> bind(perform_lease)
    |> case do
      {:ok, {port_and_ref, state_new}} ->
        {:reply, {:ok, port_and_ref}, state_new}

      {:error, _} = error ->
        {:reply, error, state_current}

      _ ->
        {:reply, {:error, :unknown}, state_current}
    end
  end

  def handle_call(
        {:lease_port_for, receiver_pid},
        _from,
        state_current
      )
      when not is_pid(receiver_pid) do
    {:reply, {:error, :badarg}, state_current}
  end

  def handle_call(
        {:lease_port_for, receiver_pid},
        {_, call_ref},
        %{ports: ports, leases: leases} = state_current
      )
      when is_pid(receiver_pid) do
    {result, ports_remaining} = :queue.out(ports)

    perform_lease = fn port ->
      state_updated_ports = %{state_current | ports: ports_remaining}

      lease_port_to(port, {receiver_pid, call_ref}, leases, state_updated_ports)
    end

    result
    |> queue_out_to_result()
    |> bind(perform_lease)
    |> case do
      {:ok, {port_and_ref, state_new}} ->
        {:reply, {:ok, port_and_ref}, state_new}

      {:error, _} = error ->
        {:reply, error, state_current}

      _ ->
        {:reply, {:error, :unknown}, state_current}
    end
  end

  def handle_call(
        :get_state,
        _from,
        state
      ) do
    {:reply, state, state}
  end

  def handle_call({:release_port, leased_port}, _from, state_current)
      when not is_integer(leased_port) or not (leased_port >= 0 and leased_port <= 65535) do
    {:reply, {:error, :badarg}, state_current}
  end

  def handle_call(
        {:release_port, leased_port},
        {caller_pid, _},
        %{leases: leases} = state
      )
      when is_integer(leased_port) and leased_port >= 0 and leased_port <= 65535 do
    releaser = fn {pid, _} ->
      case pid == caller_pid do
        true -> {:ok, release_port(leased_port, state)}
        false -> {:error, :invalid_origin}
      end
    end

    DualMap.fetch_left(leases, leased_port)
    ~> releaser.()
    |> case do
      {:ok, state_new} -> {:reply, :ok, state_new}
      {:error, result_err} -> {:reply, result_err, state}
    end
  end

  def handle_call(_, _from, state) do
    {:reply, {:error, :invalid_call}, state}
  end

  def handle_info({:DOWN, ref, :process, _object, _reason}, state) do
    state_new = release_port_via_ref(ref, state)

    {:noreply, state_new}
  end

  defp queue_out_to_result(queue_out) do
    case queue_out do
      {:value, port} -> {:ok, port}
      :empty -> {:error, :no_available}
    end
  end

  defp lease_port_to(port, {pid, call_ref} = lease_to, leases, state) do
    monitor_ref = Process.monitor(pid)

    update_leases = fn leases_updated ->
      %{state | leases: leases_updated}
    end

    DualMap.put_new(leases, {port, monitor_ref}, lease_to)
    |> fmap(update_leases)
    |> case do
      {:error, _} = result_err ->
        Process.demonitor(monitor_ref)
        result_err

      {:ok, new_state} ->
        {:ok, {{port, call_ref}, new_state}}
    end
  end

  defp release_port(port, %{ports: ports, leases: leases} = state) do
    DualMap.associated_right(leases, port)
    |> fmap(fn
      {:assoc, ref} ->
        Process.demonitor(ref)

      :nothing ->
        raise InvalidState, "monitor reference lookup failed for port #{port}"
    end)

    ports_updated = :queue.in(port, ports)
    leases_updated = DualMap.delete_left(leases, port)

    %{state | ports: ports_updated, leases: leases_updated}
  end

  defp release_port_via_ref(ref, %{ports: ports, leases: leases} = state) do
    extract_port! = fn
      {:assoc, port} -> port
      :nothing -> raise InvalidState, "port lookup failed for ref #{ref}"
    end

    DualMap.associated_left(leases, ref)
    |> fmap(extract_port!)
    |> case do
      {:ok, port} ->
        ports_updated = :queue.in(port, ports)
        leases_updated = DualMap.delete_right(leases, ref)

        %{state | ports: ports_updated, leases: leases_updated}

      {:error, _} ->
        state
    end
  end
end
