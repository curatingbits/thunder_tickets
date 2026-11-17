module Market
  # One game's research for the seat map: every listing the snapshot read,
  # what it did to the market value, and where it sits. A listing has seats
  # when the research opened it (rows near ours); otherwise only its row is
  # known, and the map lights the whole row rather than guess.
  class SeatMap
    # The roles, in list order, with what each did to the market value.
    ROLES = {
      "comparable" => "Set the market value",
      "baseline" => "Section baseline",
      "context" => "Read for context",
      "set_aside" => "Set aside"
    }.freeze

    Entry = Data.define(:id, :section, :row, :seats, :price, :role, :share, :note, :on_map)

    attr_reader :snapshot

    def initialize(snapshot, settings:, layout: Venue::Layout.paycom, our_all_in: nil)
      @snapshot = snapshot
      @settings = settings
      @layout = layout
      @our_all_in = our_all_in
    end

    def entries
      @entries ||= begin
        observations = @snapshot.observations.to_a
        total = observations.select { |o| comparable?(o) }.sum { |o| o.weight.to_f }
        observations.map { |o| entry(o, total) }
                    .sort_by { |e| [ ROLES.keys.index(e.role), -(e.share || 0), e.price ] }
      end
    end

    def groups = entries.group_by(&:role)

    def ours
      { section: @settings.our_section, row: @settings.our_row,
        seats: (1..@snapshot.game.season.num_seats).to_a, all_in: @our_all_in&.round(2) }
    end

    # The span the price colors stretch over: the middle 90%, so one $1,100
    # placeholder doesn't wash every other listing into the same color.
    def price_range
      prices = entries.reject { |e| e.role == "set_aside" }.map(&:price).sort
      prices = entries.map(&:price).sort if prices.empty?
      return if prices.empty?

      low = Stats.quantile(prices, 0.05).floor
      high = Stats.quantile(prices, 0.95).ceil
      high > low ? [ low, high ] : [ low, low + 1 ]
    end

    def to_client
      {
        game: @snapshot.game_id, market_value: @snapshot.market_value&.to_f, ours: ours, range: price_range,
        listings: entries.select(&:on_map).map do |e|
          { id: e.id, section: e.section, row: e.row, seats: e.seats, price: e.price, role: e.role, share: e.share }
        end
      }
    end

    private

    def comparable?(o) = o.kept? && o.tier.present? && o.tier <= 3

    def entry(o, total)
      role =
        if !o.kept? then "set_aside"
        elsif o.tier.nil? then "context"
        elsif o.tier <= 3 then "comparable"
        else "baseline"
        end
      share = (o.weight.to_f / total * 100).round(1) if role == "comparable" && total.positive?
      seats = o.seat_numbers
      on_map = @layout.row(o.section, o.row).present?
      Entry.new(id: o.id, section: o.section, row: o.row, seats: seats, price: o.price.to_f, role: role,
                share: share, note: note(o, role, share, on_map), on_map: on_map)
    end

    def note(o, role, share, on_map)
      text =
        case role
        when "comparable"
          equivalent = o.dd_equivalent_price&.to_f
          [ ("#{share.round}% of the weight" if share),
            ("worth #{ActiveSupport::NumberHelper.number_to_currency(equivalent)} in row #{@settings.our_row}" if equivalent && (equivalent - o.price.to_f).abs >= 0.5) ]
            .compact.join(" · ")
        when "baseline" then "part of section #{@settings.our_section}'s typical price"
        when "context"
          if @settings.context_sections.include?(o.section)
            "context section, never priced"
          elsif !@settings.pricing_sections.include?(o.section)
            "section #{o.section} isn't compared"
          elsif (d = RowOrder.distance(o.row, @settings.our_row))
            "#{d.abs} rows from #{@settings.our_row}, too far to compare"
          else
            "not near our seats"
          end
        else MarketObservation::EXCLUSION_LABELS.fetch(o.excluded_reason, o.excluded_reason)
        end
      on_map ? text : [ text, "not on the map" ].reject(&:blank?).join(" · ")
    end
  end
end
