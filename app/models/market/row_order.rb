module Market
  # Section 101 front to back (confirmed with Duggan; seen across 35 games):
  # courtside FL rows, then the double-letter rows, then single letters.
  # Paycom skips I and O. Neighbor sections 102 and 120 are assumed to match.
  module RowOrder
    ORDER = %w[FL1 FL2 FL3 AA BB CC DD EE FF GG HH JJ KK LL MM NN PP QQ RR SS TT UU
               J K L M N P Q R S T U].freeze

    def self.courtside?(row)
      row.to_s.strip.upcase.start_with?("FL")
    end

    def self.rank(row)
      ORDER.index(row.to_s.strip.upcase)
    end

    # Rows behind `from` are positive, rows in front negative; nil if either
    # row is unknown.
    def self.distance(row, from)
      a = rank(row)
      b = rank(from)
      a - b if a && b
    end
  end
end
