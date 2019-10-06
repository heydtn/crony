defmodule Crony.Browser.PortPool.Ports do
  use Brex.Result

  alias __MODULE__

  defstruct data: :queue.new()

  @typep queue(a) :: {[a], [a]}
  @typep queue_output(a) :: {:value, a} | :empty

  @type port_number :: integer()

  @type t :: %Ports{
          data: queue(port_number())
        }

  @spec from_range(Range.t()) :: t()
  def from_range(range) do
    range
    |> Enum.to_list()
    |> :queue.from_list()
    |> (&%Ports{data: &1}).()
  end

  @spec from_list([port_number()]) :: t()
  def from_list(list) do
    %Ports{data: :queue.from_list(list)}
  end

  @spec put(t(), port_number()) :: t()
  def put(%Ports{data: data} = ports, port)
      when is_integer(port) and port >= 0 and port <= 65535 do
    %{ports | data: :queue.in(port, data)}
  end

  def put(%Ports{}, _arg) do
    raise ArgumentError, "invalid port"
  end

  @spec get(t()) :: {:ok, {port_number(), queue(port_number())}} | {:error, any}
  def get(%Ports{data: data} = ports) do
    {queue_out, ports_remaining} = :queue.out(data)

    queue_out
    |> queue_out_to_result()
    |> fmap(fn port ->
      {port, %{ports | data: ports_remaining}}
    end)
  end

  @spec queue_out_to_result(queue_output(port_number())) ::
          {:ok, port_number()} | {:error, :none_available}
  defp queue_out_to_result(queue_out) do
    case queue_out do
      {:value, port} -> {:ok, port}
      :empty -> {:error, :none_available}
    end
  end
end
