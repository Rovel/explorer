defmodule Explorer.SharedTest do
  use ExUnit.Case, async: true
  alias Explorer.Shared

  defmodule FakeImpl do
    defstruct op: nil

    def ping(left, right) do
      send(self(), {:pong, left, right})
      :ok
    end
  end

  describe "impl!/1" do
    test "with a series" do
      assert Shared.impl!(series()) == Explorer.PolarsBackend.Series
    end

    test "with a lazy series" do
      assert Shared.impl!(lazy_series()) == Explorer.Backend.LazySeries
    end

    test "with list of series" do
      assert Shared.impl!([series(), series()]) == Explorer.PolarsBackend.Series
    end

    test "with list of lazy series" do
      assert Shared.impl!([lazy_series(), lazy_series()]) == Explorer.Backend.LazySeries
    end

    test "with list of series and lazy series" do
      assert_raise RuntimeError, fn -> Shared.impl!([series(), lazy_series()]) end
      assert_raise RuntimeError, fn -> Shared.impl!([lazy_series(), series()]) end
    end
  end

  describe "impl!/2" do
    test "with two series" do
      assert Shared.impl!(series(), series()) == Explorer.PolarsBackend.Series
    end

    test "with two lazy series" do
      assert Shared.impl!(lazy_series(), lazy_series()) == Explorer.Backend.LazySeries
    end

    test "with a series and a lazy series" do
      assert_raise RuntimeError, fn -> Shared.impl!(series(), lazy_series()) end
      assert_raise RuntimeError, fn -> Shared.impl!(lazy_series(), series()) end
    end
  end

  describe "series_impl!/1" do
    test "with series" do
      assert Shared.series_impl!([series(), series()]) == Explorer.PolarsBackend.Series
    end

    test "with lazy sereis" do
      assert Shared.series_impl!([lazy_series(), lazy_series()]) == Explorer.Backend.LazySeries
    end

    test "with a series and a lazy series" do
      assert Shared.series_impl!([1, series(), lazy_series()]) == Explorer.Backend.LazySeries
      assert Shared.series_impl!([lazy_series(), 2, series()]) == Explorer.Backend.LazySeries
    end

    test "without a series nor a lazy series" do
      assert_raise ArgumentError, fn -> Shared.series_impl!([1, 2]) end
    end
  end

  describe "apply_binary_op_impl/1" do
    test "applies when series is on the left-hand side" do
      :ok = Shared.apply_binary_op_impl(:ping, %{data: %FakeImpl{}}, 42)

      assert_receive {:pong, %{data: %FakeImpl{}}, 42}
    end

    test "applies when series is on the right-hand side" do
      :ok = Shared.apply_binary_op_impl(:ping, 42, %{data: %FakeImpl{}})

      assert_receive {:pong, 42, %{data: %FakeImpl{}}}
    end

    test "raise an error if is not possible to find the implementation" do
      error_message =
        "could not find implementation for function :ping. " <>
          "One of the sides must be a series, but they are: " <>
          "42 (left-hand side) and 13 (right-hand side)."

      assert_raise ArgumentError, error_message, fn ->
        Shared.apply_binary_op_impl(:ping, 42, 13)
      end
    end
  end

  defp series(data \\ [1]) do
    Explorer.Series.from_list(data, backend: Explorer.PolarsBackend)
  end

  defp lazy_series() do
    data = Explorer.Backend.LazySeries.new(:column, ["col_a"])
    Explorer.Backend.Series.new(data, :integer)
  end
end
