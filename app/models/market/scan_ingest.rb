module Market
  # Turns one game's scan into an immutable snapshot plus its observations,
  # in one transaction. Replaying the same scan returns the stored snapshot;
  # a different scan for the same run and game is refused, never merged.
  # Never touches tickets or anything financial. With sync_listings (the
  # automated research), it also brings our Ticketmaster listing in line with
  # what the scan saw in our row (Listings::ResearchSync).
  class ScanIngest
    class Conflict < StandardError; end
    class Invalid < StandardError; end

    Result = Data.define(:snapshot, :replayed, :our_listing)

    TICKET_TYPES = %w[verified_resale standard_admission other].freeze
    MAX_LISTINGS = 2_000

    def initialize(run:, game:, payload:, manual: false, sync_listings: false, now: Time.current)
      @run = run
      @game = game
      @payload = payload.to_h.deep_symbolize_keys
      @manual = manual
      @sync_listings = sync_listings
      @now = now
    end

    def call
      listings = normalized_listings
      digest = Digest::SHA256.hexdigest(JSON.generate([ listings, @payload[:event_id], quantity ]))

      if (existing = @run.market_snapshots.find_by(game: @game))
        return Result.new(existing, true, nil) if existing.payload_digest == digest

        raise Conflict, "this run already has a different scan for #{@game.opponent.name} on #{@game.game_date}"
      end
      check_event_date!

      sync = nil
      snapshot = MarketSnapshot.transaction do
        sync = sync_our_listing(listings)
        snapshot = MarketSnapshot.create!(snapshot_attributes(listings, digest))
        sync&.record_events!(snapshot)
        rows = @observations.map do |o|
          o.to_h.except(:price, :dd_equivalent_price).merge(
            market_snapshot_id: snapshot.id, price: o.price.round(2), dd_equivalent_price: o.dd_equivalent_price,
            weight: o.weight.round(4), created_at: @now
          )
        end
        MarketObservation.insert_all!(rows) if rows.any?
        remember_event!
        snapshot
      end
      Result.new(snapshot, false, sync&.result)
    end

    private

    # Only the automated research, on a current scan of an upcoming game: a
    # pasted or backfilled scan says nothing reliable about our listing today.
    def sync_our_listing(listings)
      return unless @sync_listings && !@manual
      return unless captured_at >= @now - 1.day && @game.game_date >= captured_at.to_date

      sync = Listings::ResearchSync.new(game: @game, listings: listings, settings: Settings.for(@game.season),
                                        scroll_complete: scroll_complete?, now: captured_at)
      sync.apply
      @game.listings.reset
      @game.listing_events.reset
      sync
    end

    def quantity
      Integer(@payload[:quantity_filter] || 2)
    end

    def normalized_listings
      raw = Array(@payload[:listings])
      raise Invalid, "too many listings (#{raw.size})" if raw.size > MAX_LISTINGS

      raw.each_with_index.map do |l, i|
        l = l.to_h.symbolize_keys
        price = Float(l[:price].to_s.delete("$,"), exception: false)
        raise Invalid, "listing #{i + 1} has no usable price" unless price&.positive?
        raise Invalid, "listing #{i + 1} has no section" if l[:section].blank?

        type = l[:ticket_type].presence || "verified_resale"
        raise Invalid, "listing #{i + 1} has an unknown ticket_type #{type}" unless TICKET_TYPES.include?(type)

        seats = Array(l[:seats]).map(&:to_i).select(&:positive?).uniq.sort.presence
        { position: (l[:position] || i + 1).to_i, section: l[:section].to_s.strip.upcase, row: l[:row].to_s.strip.upcase.presence,
          price: price.round(2), ticket_type: type, raw_label: l[:raw_label].to_s.first(300) }.merge(seats ? { seats: seats } : {})
      end
    end

    # The scan's event must be this game: catches a click-through that landed
    # on the wrong night.
    def check_event_date!
      return if @payload[:event_date].blank?

      date = Date.iso8601(@payload[:event_date].to_s)
      return if date == @game.game_date

      raise Invalid, "event date #{date} doesn't match the game on #{@game.game_date}"
    rescue Date::Error
      raise Invalid, "event_date #{@payload[:event_date].inspect} isn't YYYY-MM-DD"
    end

    def snapshot_attributes(listings, digest)
      season = @game.season
      settings = Settings.for(season)
      status = @game.listing_status(now: @now)
      fee = FeeModel.detect(listings.select { |l| l[:ticket_type] != "standard_admission" }.map { |l| l[:price] },
                            settings.buyer_fee_multiplier)
      our_all_in = Assessment.our_all_in(status, fee.multiplier)
      comparables = Comparables.new(settings)
      @observations = Outliers.apply(listings.map { |l| comparables.classify(l) }, settings, our_all_in: our_all_in)

      row_premium, row_premium_source = RowPremium.for(season, settings, now: @now)
      valuation = Valuation.call(@observations, settings, row_premium: row_premium)
      breakdown = Confidence.breakdown(valuation, scroll_complete: scroll_complete?, manual: @manual)
      confidence = Confidence.total(breakdown, @now, now: @now, fee_verified: fee.verified)

      previous = @game.market_snapshots.valid.where(captured_at: ..(captured_at - 4.days)).latest_first.first
      change = (((valuation.market / previous.market_value.to_f) - 1) * 100).round(2) if previous&.market_value && valuation.market
      supply_change = valuation.section_count - previous.section_count if previous
      supply_change_pct = (supply_change * 100.0 / previous.section_count) if previous && previous.section_count.positive?

      days = @game.days_until(captured_at.to_date)
      strategy, reason = Strategy.choose(days: days, change_pct: change, supply_change_pct: supply_change_pct, confidence: confidence)
      recommended_all_in = { "competitive" => valuation.competitive, "market" => valuation.market, "premium" => valuation.premium }[strategy]
      rounding = { "competitive" => :floor, "market" => :round, "premium" => :ceil }[strategy]

      {
        import_run: @run, game: @game, captured_at: captured_at, days_to_game: days,
        event_id: @payload[:event_id].presence, event_url: @payload[:event_url].presence, event_title: @payload[:event_title].to_s.first(200).presence,
        quantity_filter: quantity, event_total_listings: @payload[:event_total_listings],
        captured_count: listings.size, scroll_complete: scroll_complete?, payload_digest: digest,
        engine_version: ENGINE_VERSION, settings_used: settings.to_h.merge(row_premium: row_premium),
        tier1_count: count_tier(1), tier2_count: count_tier(2), tier3_count: count_tier(3),
        section_count: valuation.section_count, excluded_count: @observations.count { |o| !o.kept? },
        comp_weight: valuation.weight.round(3),
        comp_min: valuation.comp_min, comp_p25: valuation.comp_p25&.round(2), comp_median: valuation.comp_median&.round(2),
        comp_mean: valuation.comp_mean&.round(2), comp_p75: valuation.comp_p75&.round(2), comp_max: valuation.comp_max,
        section_min: valuation.section_min, section_median: valuation.section_median&.round(2), section_max: valuation.section_max,
        near_raw_median: valuation.near_raw_median&.round(2), row_premium: row_premium, row_premium_source: row_premium_source,
        primary_min_price: @observations.reject(&:resale?).map(&:price).min,
        distribution: distribution,
        buyer_fee_multiplier: fee.multiplier, fee_evidence_share: fee.share, fee_verified: fee.verified,
        competitive_price: valuation.competitive, market_value: valuation.market, premium_price: valuation.premium,
        recommended_strategy: (strategy unless valuation.insufficient),
        recommended_list_price: (recommended_all_in && FeeModel.list_price(recommended_all_in, fee.multiplier, rounding: rounding)),
        rationale: valuation.insufficient ? [ "not enough listings near our seats to price them" ] : rationale(change, valuation, row_premium, reason, fee.multiplier),
        confidence: confidence, confidence_breakdown: breakdown,
        our_ask_price: status.ask_prices.first, our_ask_basis: status.listings.find(&:listing?)&.ask_price_basis,
        our_all_in: our_all_in&.round(2),
        assessment: Assessment.call(listing_status: status, our_all_in: our_all_in, market_value: valuation.market,
                                    confidence: confidence, settings: settings),
        observed_our_listing: @observations.any? { |o| o.excluded_reason == "ours" },
        previous_snapshot: previous, market_value_change_pct: change, section_count_change: supply_change
      }
    end

    def captured_at
      @captured_at ||= begin
        Time.zone.parse(@payload[:captured_at].to_s) || @now
      rescue ArgumentError
        @now
      end.then { |t| [ t, @now ].min }
    end

    def scroll_complete?
      @payload.fetch(:scroll_complete, true) != false
    end

    def count_tier(tier)
      @observations.count { |o| o.comparable? && o.tier == tier }
    end

    # $25 buckets of every kept resale price in our section and neighbors.
    def distribution
      @observations.select { |o| o.kept? && o.resale? }.group_by { |o| ((o.price / 25).floor * 25).to_i }
                   .transform_values(&:size).sort.to_h.transform_keys(&:to_s)
    end

    def rationale(change, valuation, row_premium, reason, multiplier)
      near = valuation.comparable_values.size
      lines = [ reason ]
      lines << "market #{change.positive? ? 'up' : 'down'} #{change.abs.round}% since the last scan" if change && change.abs >= 1
      lines << if near.zero?
        "no listings near row #{Settings.for(@game.season).our_row}; based on the section's typical price x #{row_premium}"
      else
        "#{near} comparable listing#{'s' unless near == 1} near our seats"
      end
      cost = @game.cost_per_ticket.to_f
      if valuation.market && valuation.market / multiplier < cost
        lines << "market list price is below our #{ActiveSupport::NumberHelper.number_to_currency(cost)} cost per seat (for reference)"
      end
      lines
    end

    # Fill the game's Ticketmaster event the first time it's seen; a
    # different event later is logged, never overwritten.
    def remember_event!
      id = @payload[:event_id].presence
      return unless id

      if @game.ticketmaster_event_id.blank?
        @game.update_columns(ticketmaster_event_id: id, ticketmaster_url: @payload[:event_url].presence)
      elsif @game.ticketmaster_event_id != id
        @run.log_error!("event id mismatch", game_id: @game.id, stored: @game.ticketmaster_event_id, scanned: id)
      end
    end
  end
end
