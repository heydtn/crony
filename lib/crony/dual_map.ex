defmodule Crony.DualMap do
  use Brex.Result

  alias __MODULE__

  @compile {:inline, deassociated_right_for: 2, deassociated_left_for: 2}

  defstruct left: %{},
            right: %{}

  @type t(left, right, val) :: %DualMap{
          left: %{required(left) => {val, right}},
          right: %{required(right) => {val, left}}
        }

  def(put_new(dualmap, {key_left, key_right}, value)) do
    preexisting_key? =
      Map.has_key?(dualmap.left, key_left) || Map.has_key?(dualmap.right, key_right)

    case preexisting_key? do
      true ->
        {:error, :key_collision}

      false ->
        {:ok,
         %{
           dualmap
           | left: Map.put(dualmap.left, key_left, {value, {:assoc, key_right}}),
             right: Map.put(dualmap.right, key_right, {value, {:assoc, key_left}})
         }}
    end
  end

  def put_brutal(dualmap, {key_left, key_right}, value) do
    new_right =
      case dualmap.left do
        %{^key_left => {_, {:assoc, key}}} ->
          Map.delete(dualmap.right, key)

        _ ->
          dualmap.right
      end
      |> Map.put(key_right, {value, {:assoc, key_left}})

    new_left =
      case dualmap.right do
        %{^key_right => {_, {:assoc, key}}} ->
          Map.delete(dualmap.left, key)

        _ ->
          dualmap.left
      end
      |> Map.put(key_left, {value, {:assoc, key_right}})

    %{
      dualmap
      | left: new_left,
        right: new_right
    }
  end

  def put_unsafe(dualmap, {key_left, key_right}, value) do
    new_right =
      case dualmap.left do
        %{^key_left => {_, {:assoc, key}}} ->
          deassociated_right_for(dualmap, key)

        _ ->
          dualmap.right
      end
      |> Map.put(key_right, {value, {:assoc, key_left}})

    new_left =
      case dualmap.right do
        %{^key_right => {_, {:assoc, key}}} ->
          deassociated_left_for(dualmap, key)

        _ ->
          dualmap.left
      end
      |> Map.put(key_left, {value, {:assoc, key_right}})

    %{
      dualmap
      | left: new_left,
        right: new_right
    }
  end

  def delete_left(dualmap, key_left) do
    case Map.has_key?(dualmap.left, key_left) do
      true ->
        {_, key_right} = Map.fetch!(dualmap.left, key_left)

        new_right =
          case key_right do
            :nothing -> dualmap.right
            {:assoc, key} -> Map.delete(dualmap.right, key)
          end

        %{
          dualmap
          | left: Map.delete(dualmap.left, key_left),
            right: new_right
        }

      false ->
        dualmap
    end
  end

  def delete_right(dualmap, key_right) do
    case Map.has_key?(dualmap.right, key_right) do
      true ->
        {_, key_left} = Map.fetch!(dualmap.right, key_right)

        new_left =
          case key_left do
            :nothing -> dualmap.left
            {:assoc, key} -> Map.delete(dualmap.left, key)
          end

        %{
          dualmap
          | left: new_left,
            right: Map.delete(dualmap.right, key_right)
        }

      false ->
        dualmap
    end
  end

  def fetch_left(dualmap, key_left) do
    Map.fetch(dualmap.left, key_left)
    |> normalize_error(:not_found)
    |> fmap(fn {value, _} ->
      value
    end)
  end

  def fetch_right(dualmap, key_right) do
    Map.fetch(dualmap.right, key_right)
    |> normalize_error(:not_found)
    |> fmap(fn {value, _} ->
      value
    end)
  end

  def associated_right(dualmap, key_left) do
    Map.fetch(dualmap.left, key_left)
    |> normalize_error(:not_found)
    |> fmap(fn {_, key_right} ->
      key_right
    end)
  end

  def associated_left(dualmap, key_right) do
    Map.fetch(dualmap.right, key_right)
    |> normalize_error(:not_found)
    |> fmap(fn {_, key_left} ->
      key_left
    end)
  end

  def keys(dualmap) do
    Enum.map(dualmap.left, fn {left, {_, right}} ->
      {{:assoc, left}, right}
    end)
  end

  def keys_left(dualmap) do
    Enum.map(dualmap.left, fn {left, _} ->
      left
    end)
  end

  def keys_right(dualmap) do
    Enum.map(dualmap.right, fn {right, _} ->
      right
    end)
  end

  def to_list(dualmap) do
    lefts =
      Stream.map(dualmap.left, fn {left, {value, right}} ->
        {{{:assoc, left}, right}, value}
      end)

    dualmap.right
    |> Stream.filter(fn
      {right, {value, :nothing}} -> true
      _ -> false
    end)
    |> Stream.map(fn {right, {value, _}} ->
      {{:nothing, {:assoc, right}}, value}
    end)
    |> Stream.concat(lefts)
    |> Enum.to_list()
  end

  defp deassociated_right_for(dualmap, key) do
    Map.fetch!(dualmap.right, key)
    |> case do
      {value, {:assoc, _}} ->
        Map.put(dualmap.right, key, {value, :nothing})

      _ ->
        dualmap.right
    end
  end

  defp deassociated_left_for(dualmap, key) do
    Map.fetch!(dualmap.left, key)
    |> case do
      {value, {:assoc, _}} ->
        Map.put(dualmap.left, key, {value, :nothing})

      _ ->
        dualmap.left
    end
  end
end

defimpl Inspect, for: Crony.DualMap do
  import Inspect.Algebra

  def inspect(dualmap, _opts) do
    inspect_opts = %Inspect.Opts{}

    dualmap_renderer = fn {{left, right}, value}, _opts ->
      rl =
        case left do
          {:assoc, key} -> inspect(key)
          :nothing -> ""
        end

      rr =
        case right do
          {:assoc, key} -> inspect(key)
          :nothing -> ""
        end

      "{#{rl},#{rr}} => #{inspect(value)}"
    end

    concat([
      "#DualMap<",
      container_doc(
        "%{",
        Crony.DualMap.to_list(dualmap),
        "}",
        inspect_opts,
        dualmap_renderer
      ),
      ">"
    ])
  end
end
