defmodule Crony.Browser.PortPool.State do
  use Brex.Result

  alias Crony.Browser.PortPool.{Ports, Leases}

  alias __MODULE__

  @enforce_keys [:ports]
  defstruct [:ports, leases: %Leases{}]

  @type t :: %State{
          ports: Ports.t(),
          leases: Leases.t()
        }

  def init(port_range) do
    %State{
      ports: Ports.from_range(port_range),
      leases: %Leases{}
    }
  end

  @spec lease_to(t(), pid(), reference()) ::
          {:error, any} | {:ok, any}
  def lease_to(%State{ports: ports, leases: leases} = state, leaser_pid, call_ref) do
    add_lease = fn port ->
      Leases.lease_to(leases, port, leaser_pid, call_ref)
    end

    Ports.get(ports)
    |> bind(fn {port, ports_updated} ->
      add_lease.(port)
      |> fmap(fn leases_updated ->
        {port, %{state | ports: ports_updated, leases: leases_updated}}
      end)
    end)
  end

  def release_by_port(%State{ports: ports, leases: leases} = state, port) do
    Leases.release_by_port(leases, port)
    |> fmap(fn leases_updated ->
      ports_updated = Ports.put(ports, port)

      %{state | ports: ports_updated, leases: leases_updated}
    end)
  end

  def release_by_monitor(%State{ports: ports, leases: leases} = state, monitor) do
    Leases.release_by_monitor(leases, monitor)
    |> fmap(fn {port, leases_updated} ->
      ports_updated = Ports.put(ports, port)

      %{state | ports: ports_updated, leases: leases_updated}
    end)
  end
end
