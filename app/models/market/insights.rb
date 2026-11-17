module Market
  # Patterns in Ticketmaster asks near our seats, across games and scans.
  # Each value is compared with the typical game in the same scan, so a week
  # when the whole market moved doesn't skew a comparison. Every figure says
  # how many games and scans it rests on, and with too little data a section
  # says so instead of guessing. These are asking prices, not sales.
  class Insights
    MIN_GAMES = 3
    WEEKEND_DAYS = [ 5, 6, 0 ].freeze # Friday, Saturday, Sunday
    DAYS_OUT = [
      [ "week", "Within a week", 0..7 ],
      [ "three_weeks", "1 to 3 weeks out", 8..21 ],
      [ "eight_weeks", "3 to 8 weeks out", 22..56 ],
      [ "later", "Over 8 weeks out", 57.. ]
    ].freeze

    # vs_typical_pct: the median of each snapshot's value against its scan's
    # median game, in percent.
    Group = Data.define(:key, :label, :games, :scans, :median_value, :vs_typical_pct)
    SupplyPoint = Data.define(:run, :captured_on, :games, :listings_per_game, :nearby_per_game)
    Sale = Data.define(:ticket, :snapshot, :market_list, :vs_market_pct)

    attr_reader :season

    def initialize(season)
      @season = season
    end

    # Valid snapshots with a market value, oldest first.
    def snapshots
      @snapshots ||= MarketSnapshot.valid.where.not(market_value: nil)
                                   .joins(:game).where(games: { season_id: season.id })
                                   .includes(:import_run, game: :opponent).order(:captured_at, :id).to_a
    end

    # Each game's most recent snapshot.
    def latest
      @latest ||= snapshots.group_by(&:game_id).values.map(&:last)
    end

    def scan_count = snapshots.map(&:import_run_id).uniq.size
    def game_count = latest.size
    def enough? = game_count >= MIN_GAMES
    def typical_value = Stats.median(latest.map { |s| s.market_value.to_f })&.round

    # Every scan counts here: as runs accumulate, each game shows up at
    # several distances from tipoff.
    def by_days_out
      DAYS_OUT.filter_map do |key, label, range|
        snaps = snapshots.select { |s| range.cover?(s.days_to_game) }
        group(key, label, snaps) if snaps.any?
      end
    end

    def by_opponent
      latest.group_by { |s| s.game.opponent }
            .map { |opponent, snaps| group(opponent.id, opponent.name, snaps) }
            .sort_by { |g| [ -g.vs_typical_pct, g.label ] }
    end

    def by_day_of_week
      weekend, weeknight = latest.partition { |s| WEEKEND_DAYS.include?(s.game.game_date.wday) }
      [ group("weekend", "Friday to Sunday", weekend), group("weeknight", "Monday to Thursday", weeknight) ]
        .select { |g| g.games.positive? }
    end

    # Listings seen per game in each scan. A listing that stops appearing may
    # have sold, been withdrawn or been repriced out of range.
    def supply
      @supply ||= snapshots.group_by(&:import_run).map do |run, snaps|
        SupplyPoint.new(run: run, captured_on: snaps.map(&:captured_at).min.to_date, games: snaps.size,
                        listings_per_game: mean(snaps.map(&:section_count)),
                        nearby_per_game: mean(snaps.map { |s| s.tier1_count + s.tier2_count + s.tier3_count }))
      end.sort_by(&:captured_on)
    end

    # Our sales that recorded a list price, against the market's list-price
    # equivalent in the latest scan before the sale.
    def sales_vs_market
      @sales_vs_market ||= sales_after_a_scan.filter_map do |ticket, snapshot|
        next unless ticket.list_price_at_sale

        market_list = snapshot.market_value.to_f / snapshot.buyer_fee_multiplier.to_f
        Sale.new(ticket: ticket, snapshot: snapshot, market_list: market_list.round(2),
                 vs_market_pct: ((ticket.list_price_at_sale.to_f / market_list - 1) * 100).round)
      end
    end

    # Sales after a scan that can't be compared: no list price was recorded.
    def uncompared_sales_count
      sales_after_a_scan.count { |ticket, _| ticket.list_price_at_sale.nil? }
    end

    private

    def sales_after_a_scan
      @sales_after_a_scan ||= begin
        by_game = snapshots.group_by(&:game_id)
        Ticket.where(game_id: by_game.keys).where.not(sold_at: nil).includes(game: :opponent).order(:sold_at).filter_map do |ticket|
          snapshot = by_game[ticket.game_id].select { |s| s.captured_at <= ticket.sold_at }.last
          [ ticket, snapshot ] if snapshot
        end
      end
    end

    def group(key, label, snaps)
      relatives = snaps.filter_map { |s| relative(s) }
      Group.new(key: key, label: label, games: snaps.map(&:game_id).uniq.size, scans: snaps.map(&:import_run_id).uniq.size,
                median_value: Stats.median(snaps.map { |s| s.market_value.to_f })&.round,
                vs_typical_pct: relatives.any? ? (Stats.median(relatives) * 100).round : 0)
    end

    def relative(snapshot)
      median = scan_medians[snapshot.import_run_id]
      snapshot.market_value.to_f / median - 1 if median&.positive?
    end

    def scan_medians
      @scan_medians ||= snapshots.group_by(&:import_run_id)
                                 .transform_values { |snaps| Stats.median(snaps.map { |s| s.market_value.to_f }) }
    end

    def mean(values) = values.empty? ? 0 : (values.sum.to_f / values.size).round(1)
  end
end
