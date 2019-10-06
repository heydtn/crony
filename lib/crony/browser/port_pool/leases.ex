defmodule Crony.Browser.PortPool.Leases do
  use Brex.Result

  alias Crony.DualMap
  alias __MODULE__

  defstruct data: %DualMap{}

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
    |> fmap(fn _ ->
      data_updated = DualMap.delete_left(data, port)
      %{leases | data: data_updated}
    end)
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
end
