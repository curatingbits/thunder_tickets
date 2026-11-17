module Market
  # Is our asking price in line with the market? Uses the live listing
  # status, so an unconfirmed listing is never judged as if it were real.
  module Assessment
    LABELS = {
      "overpriced" => "Overpriced",
      "underpriced" => "Underpriced",
      "competitive" => "Competitive",
      "not_listed" => "Not listed",
      "needs_verification" => "Needs verification",
      "insufficient_data" => "Insufficient data"
    }.freeze

    module_function

    def call(listing_status:, our_all_in:, market_value:, confidence:, settings:)
      return if listing_status.open_seats.empty? || listing_status.status.in?(%i[reserved unsold])
      return "not_listed" if listing_status.status == :not_listed
      return "needs_verification" if listing_status.status == :needs_verification || our_all_in.nil?
      return "insufficient_data" if market_value.nil? || confidence < 25

      ratio = our_all_in / market_value
      if ratio > 1 + (settings.overpriced_pct / 100.0) then "overpriced"
      elsif ratio < 1 - (settings.underpriced_pct / 100.0) then "underpriced"
      else "competitive"
      end
    end

    # Our asking price on the all-in basis the market is read in: the lowest
    # active listing, converted from list price if that's how it was entered.
    def our_all_in(listing_status, multiplier)
      prices = listing_status.listings.select(&:listing?).map do |listing|
        listing.all_in_price? ? listing.ask_price.to_f : FeeModel.all_in(listing.ask_price.to_f, multiplier)
      end
      prices.min
    end
  end
end
