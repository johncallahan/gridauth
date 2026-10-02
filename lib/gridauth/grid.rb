require "securerandom"

module Gridauth
  # The plaintext contents of a grid card. Instances only exist briefly while
  # a new card is shown to its owner; the database stores HMAC digests.
  class Grid
    MAX_COLUMNS = 26

    attr_reader :rows, :columns, :values

    def self.generate(rows: Gridauth.config.rows, columns: Gridauth.config.columns,
                      cell_length: Gridauth.config.cell_length, alphabet: Gridauth.config.alphabet)
      chars = alphabet.chars.uniq
      values = cell_keys(rows, columns).index_with do
        Array.new(cell_length) { chars[SecureRandom.random_number(chars.size)] }.join
      end
      new(rows:, columns:, values:)
    end

    # Rebuilds a grid from #to_compact output.
    def self.from_compact(string, rows:, columns:)
      cell_length = string.length / (rows * columns)
      values = cell_keys(rows, columns).each_with_index.to_h do |key, index|
        [ key, string[index * cell_length, cell_length] ]
      end
      new(rows:, columns:, values:)
    end

    def self.column_labels(columns)
      raise ArgumentError, "a grid card can have at most #{MAX_COLUMNS} columns" if columns > MAX_COLUMNS

      ("A"..).first(columns)
    end

    def self.row_labels(rows)
      (1..rows).map(&:to_s)
    end

    # Cell keys in row-major order, e.g. ["A1", "B1", ..., "A2", ...].
    def self.cell_keys(rows, columns)
      row_labels(rows).flat_map { |row| column_labels(columns).map { |column| "#{column}#{row}" } }
    end

    def initialize(rows:, columns:, values:)
      @rows = rows
      @columns = columns
      @values = values
    end

    def column_labels = self.class.column_labels(columns)
    def row_labels = self.class.row_labels(rows)
    def cell_keys = self.class.cell_keys(rows, columns)

    def [](key)
      values[key.to_s.upcase]
    end

    # Compact form small enough to keep in the (encrypted) session cookie.
    def to_compact
      cell_keys.map { |key| values.fetch(key) }.join
    end
  end
end
