defmodule Crony.Browser.PortPool.PortsTest do
  use ExUnit.Case, async: true
  alias Crony.Browser.PortPool.Ports

  use ExUnitProperties

  property "put/2 only inserts valid ports" do
    check all valid_port <- integer(0..65535),
              invalid_port <- list_of(term()),
              !(is_integer(invalid_port) && invalid_port >= 0 && invalid_port <= 65535) do
      port_store = Ports.put(Ports.from_list([]), valid_port)
      assert port_store == %Ports{data: {[valid_port], []}}

      assert_raise ArgumentError, fn ->
        Ports.put(Ports.from_list([]), invalid_port)
      end
    end
  end

  property "get/1 returns a value from the ports store in a result tuple" do
    check all valid_port <- integer(0..65535) do
      empty_store = Ports.from_list([])
      port_store = Ports.put(empty_store, valid_port)
      assert Ports.get(port_store) == {:ok, {valid_port, empty_store}}
    end

    check all _valid_port <- integer(0..65535) do
      port_store = Ports.from_list([])
      assert Ports.get(port_store) == {:error, :none_available}
    end
  end

  property "get/1 returns values that were inserted FIFO" do
    check all valid_ports <- list_of(integer(0..65535)) do
      populated_ports =
        Enum.reduce(valid_ports, %Ports{}, fn val, acc ->
          Ports.put(acc, val)
        end)

      {taken_ports, empty_queue} =
        Enum.reduce(valid_ports, {[], populated_ports}, fn _val, {acc, ports} ->
          {:ok, {port, remaining}} = Ports.get(ports)
          {[port | acc], remaining}
        end)

      assert valid_ports == Enum.reverse(taken_ports)
      assert empty_queue == Ports.from_list([])
    end
  end

  property "from_list/1 returns a Ports composed of the passed in ports" do
    check all valid_ports <- list_of(integer(0..65535)) do
      populated_ports = Ports.from_list(valid_ports)

      {taken_ports, _empty_queue} =
        Enum.reduce(valid_ports, {[], populated_ports}, fn _val, {acc, ports} ->
          {:ok, {port, remaining}} = Ports.get(ports)
          {[port | acc], remaining}
        end)

      assert valid_ports == Enum.reverse(taken_ports)
    end
  end

  property "from_range/1 returns a Ports composed of the passed in range" do
    check all lower_range <- integer(0..9999),
              upper_range <- integer(9999..19998) do
      port_range = lower_range..upper_range
      populated_ports = Ports.from_range(port_range)

      {taken_ports, _empty_queue} =
        Enum.reduce(port_range, {[], populated_ports}, fn _val, {acc, ports} ->
          {:ok, {port, remaining}} = Ports.get(ports)
          {[port | acc], remaining}
        end)

      assert Enum.to_list(port_range) == Enum.reverse(taken_ports)
    end
  end
end
