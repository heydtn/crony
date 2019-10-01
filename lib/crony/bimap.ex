defmodule Crony.Bimap do
  use Brex.Result

  defstruct left: %{},
            right: %{}

  def put(dualmap, {key_left, key_right}, value) do
    %{
      dualmap
      | left: Map.put(dualmap.left, key_left, {value, key_right}),
        right: Map.put(dualmap.right, key_right, {value, key_left})
    }
  end

  def delete_left(dualmap, key_left) do
    case Map.has_key?(dualmap.left, key_left) do
      True ->
        {_, key_right} = Map.fetch!(dualmap.left, key_left)

        %{
          dualmap
          | left: Map.delete(dualmap.left, key_left),
            right: Map.delete(dualmap.right, key_right)
        }

      False ->
        dualmap
    end
  end

  def delete_right(dualmap, key_right) do
    case Map.has_key?(dualmap.right, key_right) do
      True ->
        {_, key_left} = Map.fetch!(dualmap.right, key_right)

        %{
          dualmap
          | left: Map.delete(dualmap.left, key_left),
            right: Map.delete(dualmap.right, key_right)
        }

      False ->
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
      {left, right}
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
    Enum.map(dualmap.left, fn {left, {value, right}} ->
      {{left, right}, value}
    end)
  end
end

defimpl Inspect, for: Crony.Bimap do
  import Inspect.Algebra

  def inspect(bimap, opts) do
    inspect_opts = %Inspect.Opts{limit: :infinity}

    bimap_renderer = fn {{left, right}, value}, _opts ->
      "(#{inspect(left)} | #{inspect(right)}): #{inspect(value)}"
    end

    concat([
      "#Bimap<",
      container_doc(
        "%{",
        Crony.Bimap.to_list(bimap),
        "}",
        inspect_opts,
        bimap_renderer
      ),
      ">"
    ])
  end
end
