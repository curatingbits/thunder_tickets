module Market
  # What our unsold, unheld seats are worth at today's market values, from
  # the board's rows. All-in is what buyers would pay; list is what we'd
  # enter on Ticketmaster; payout only when the seller fee is actually known.
  # Games without market data are counted as not covered, never guessed.
  class InventoryValue
    Result = Data.define(:all_in, :list, :payout, :payout_source, :seats, :seats_covered, :games_open,
                         :games_covered, :low_confidence, :oldest_captured_at)

    def self.from(rows)
      open = rows.select { |r| r.seats_to_sell.positive? }
      covered = open.select { |r| r.snapshot&.market_value }
      all_in = covered.sum { |r| r.snapshot.market_value.to_f * r.seats_to_sell }
      list = covered.sum { |r| (r.snapshot.market_value.to_f / r.snapshot.buyer_fee_multiplier.to_f) * r.seats_to_sell }
      fee, source = FeeModel.seller_fee
      Result.new(
        all_in: all_in.round, list: list.round, payout: (fee && (list * (1 - fee)).round), payout_source: source,
        seats: open.sum(&:seats_to_sell), seats_covered: covered.sum(&:seats_to_sell),
        games_open: open.size, games_covered: covered.size,
        low_confidence: covered.count { |r| r.confidence < 45 },
        oldest_captured_at: covered.map { |r| r.snapshot.captured_at }.min
      )
    end
  end
end
