module Market
  # Ticketmaster shows buyers an all-in price: our list price x a buyer-fee
  # multiplier. In Kate's 1,053 resale prices, 1,052 were exactly a whole-
  # dollar list price x 1.215, so every scan re-checks the multiplier against
  # its own prices instead of trusting a fixed number.
  #
  # The seller fee (list price -> our payout) is never assumed: it comes from
  # sales linked to listings, or a rate set in Settings, or it's unknown.
  module FeeModel
    TOLERANCE = 0.006
    MIN_SHARE = 0.6
    SEARCH = (1150..1300).step(5).map { |n| n / 1000.0 }.freeze

    Detection = Data.define(:multiplier, :share, :verified)

    module_function

    def share(prices, multiplier)
      return 0.0 if prices.empty?

      prices.count { |p| ((p / multiplier) - (p / multiplier).round).abs <= TOLERANCE }.fdiv(prices.size)
    end

    def detect(resale_prices, configured)
      return Detection.new(configured, nil, false) if resale_prices.size < 5

      configured_share = share(resale_prices, configured)
      return Detection.new(configured, configured_share.round(3), true) if configured_share >= MIN_SHARE

      best, best_share = SEARCH.map { |m| [ m, share(resale_prices, m) ] }.max_by(&:last)
      if best_share >= MIN_SHARE
        Detection.new(best, best_share.round(3), true)
      else
        Detection.new(configured, configured_share.round(3), false)
      end
    end

    # Whole-dollar list price for an all-in target: rounded down for the
    # competitive price, up for premium, to the nearest dollar otherwise.
    def list_price(all_in, multiplier, rounding: :round)
      (all_in / multiplier).public_send(rounding)
    end

    def all_in(list, multiplier)
      (list * multiplier).round(2)
    end

    # Median seller fee measured from Ticketmaster sales that were linked to
    # a listing (payout vs list price), with how many sales it's based on.
    def measured_seller_fee
      rates = Ticket.joins(:listing).where(listings: { platform: "ticketmaster" })
                    .where.not(list_price_at_sale: nil).where("list_price_at_sale > 0")
                    .pluck(:sale_price, :list_price_at_sale)
                    .map { |payout, list| 1 - (payout / list).to_f }
      return if rates.empty?

      [ Stats.median(rates).round(4), rates.size ]
    end

    # [rate, source] or nil when unknown.
    def seller_fee
      if (measured = measured_seller_fee)
        [ measured.first, "measured from #{measured.last} sale#{'s' unless measured.last == 1}" ]
      elsif (pct = AppSetting.get("pricing.seller_fee_pct"))
        [ (pct / 100).to_f, "set in Settings" ]
      end
    end
  end
end
