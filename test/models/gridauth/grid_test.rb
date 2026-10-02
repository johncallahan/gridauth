require "test_helper"

class Gridauth::GridTest < ActiveSupport::TestCase
  test "generates a value for every cell using the configured alphabet" do
    grid = Gridauth::Grid.generate(rows: 4, columns: 6, cell_length: 3, alphabet: "XYZ")

    assert_equal 24, grid.values.size
    assert_equal %w[A1 B1 C1 D1 E1 F1], grid.cell_keys.first(6)
    assert_equal "F4", grid.cell_keys.last
    assert grid.values.values.all? { |value| value.match?(/\A[XYZ]{3}\z/) }
  end

  test "round-trips through the compact form" do
    grid = Gridauth::Grid.generate
    restored = Gridauth::Grid.from_compact(grid.to_compact, rows: grid.rows, columns: grid.columns)

    assert_equal grid.values, restored.values
  end

  test "looks up cells case-insensitively" do
    grid = Gridauth::Grid.generate

    assert_equal grid["C2"], grid["c2"]
  end

  test "rejects more columns than letters" do
    assert_raises(ArgumentError) { Gridauth::Grid.generate(columns: 27) }
  end
end
