defmodule Crony.Browser.PortPool do
  use GenServer

  use Brex.Result

  alias Crony.Bimap

  def start_link(range) do
    GenServer.start_link(__MODULE__, range, name: __MODULE__)
  end

  def init(range) do
    ip_pool =
      range
      |> Enum.to_list()
      |> :queue.from_list()

    {:ok, ip_pool}
  end

  def handle_call(
        :lease_port,
        from,
        %{ports: ports, leases: leases} = current_state
      ) do
    {result, remaining_ports} = :queue.out(ports)

    result
    |> fmap(&queue_out_to_result/1)
    |> fmap(&lease_port_to(&1, from, leases, remaining_ports))
    |> case do
      {:ok, {port_and_ref, new_state}} ->
        {:reply, {:ok, port_and_ref}, new_state}

      {:error, _} = error ->
        {:reply, error, current_state}

      _ ->
        {:reply, {:error, :unknown}, current_state}
    end
  end

  def handle_call(
        {:lease_port_for, pid},
        _from,
        %{ports: ports, leases: leases} = current_state
      ) do
    {result, remaining_ports} = :queue.out(ports)

    result
    |> fmap(&queue_out_to_result/1)
    |> fmap(&lease_port_to(&1, pid, leases, remaining_ports))
    |> case do
      {:ok, {port_and_ref, new_state}} ->
        {:reply, {:ok, port_and_ref}, new_state}

      {:error, _} = error ->
        {:reply, error, current_state}

      _ ->
        {:reply, {:error, :unknown}, current_state}
    end
  end

  def handle_call({:release_port, port}, _from, %{ports: ports, leases: leases} = state) do
    {:reply, :ok, state}
  end

  defp queue_out_to_result(queue_out) do
    case queue_out do
      {:value, port} -> {:ok, port}
      :empty -> {:error, :no_available}
    end
  end

  defp lease_port_to(port, {pid, call_ref}, leases, remaining_ports) do
    monitor_ref = Process.monitor(pid)

    new_state = %{
      addresses: remaining_ports,
      leases: Map.put(leases, port, {pid, monitor_ref, call_ref})
    }

    {{port, call_ref}, new_state}
  end
end
