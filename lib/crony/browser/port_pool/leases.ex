defmodule Crony.Browser.PortPool.Leases do
  use Brex.Result

  alias Crony.DualMap
  alias __MODULE__

  defstruct data: %DualMap{}

  def lookup_by_port(%Leases{} = leases, port) do
    app(leases, &DualMap.fetch_left(&1, port))
  end

  def lookup_by_monitor(%Leases{} = leases, monitor) do
    app(leases, &DualMap.fetch_right(&1, monitor))
  end

  def put_new(%Leases{} = leases, {port, monitor}, lease) do
    map(leases, &DualMap.put_new(&1, {port, monitor}, lease))
  end

  def port_for_monitor(%Leases{} = leases, monitor) do
    app(leases, &DualMap.associated_left(&1, monitor))
  end

  def monitor_for_port(%Leases{} = leases, port) do
    app(leases, &DualMap.associated_right(&1, port))
  end

  def lease_to(%Leases{data: data} = leases, port, leaser_pid, call_ref) do
    monitor_ref = Process.monitor(leaser_pid)

    DualMap.put_new(data, {port, monitor_ref}, {leaser_pid, call_ref})
    |> fmap(fn data_updated ->
      %{leases | data: data_updated}
    end)
    |> case do
      {:error, _} = result_err ->
        Process.demonitor(monitor_ref)
        result_err

      {:ok, _} = updated ->
        updated
    end
  end

  def release_by_port(%Leases{data: data} = leases, port) do
    DualMap.associated_right(data, port)
    |> fmap(fn
      {:assoc, ref} ->
        Process.demonitor(ref)

      :nothing ->
        raise ArgumentError, "Unable to release #{port}: could not reference monitor"
    end)
    |> fmap(&DualMap.delete_left(&1, port))
    |> fmap(&%{leases | data: &1})
  end

  def release_by_monitor(%Leases{data: data} = leases, monitor) do
    DualMap.associated_left(data, monitor)
    |> fmap(fn
      {:assoc, port} -> port
      :nothing -> raise ArgumentError, "port lookup failed for monitor #{monitor}"
    end)
    |> fmap(fn port ->
      {port, %{leases | data: DualMap.delete_right(data, monitor)}}
    end)
  end

  defp map(%Leases{data: data} = leases, fun) do
    %{leases | data: fun.(data)}
  end

  defp app(%Leases{data: data}, fun) do
    fun.(data)
  end
end
