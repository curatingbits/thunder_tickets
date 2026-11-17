require "test_helper"

class Market::EngineTest < ActiveSupport::TestCase
  setup do
    @settings = Market::Settings.for(seasons(:current))
    @classifier = Market::Comparables.new(@settings)
  end

  def obs(section, row, price, type = "verified_resale")
    @classifier.classify(section: section, row: row, price: price, ticket_type: type, position: 1)
  end

  # --- RowOrder ---------------------------------------------------------

  test "rows run courtside, doubles, then singles, skipping I and O" do
    assert_equal 3, Market::RowOrder.distance("GG", "DD")
    assert_equal(-3, Market::RowOrder.distance("AA", "DD"))
    assert_equal 1, Market::RowOrder.distance("J", "UU")
    assert_nil Market::RowOrder.rank("II")
    assert_nil Market::RowOrder.rank("O")
    assert Market::RowOrder.courtside?("fl2")
  end

  # --- Stats --------------------------------------------------------------

  test "quantiles interpolate between order statistics" do
    assert_equal 2.5, Market::Stats.quantile([ 1, 2, 3, 4 ], 0.5)
    assert_equal 1.75, Market::Stats.quantile([ 1, 2, 3, 4 ], 0.25)
    assert_nil Market::Stats.quantile([], 0.5)
  end

  test "weighted quantile puts each value mid-way through its weight" do
    # 100 holds 3/4 of the weight: its midpoint is at 0.375, 200's at 0.875.
    pairs = [ [ 100.0, 3.0 ], [ 200.0, 1.0 ] ]
    assert_equal 100.0, Market::Stats.weighted_quantile(pairs, 0.25)
    assert_in_delta 125.0, Market::Stats.weighted_quantile(pairs, 0.5), 0.001
    assert_equal 200.0, Market::Stats.weighted_quantile(pairs, 0.9)
    assert_equal 125.0, Market::Stats.weighted_mean(pairs)
  end

  # --- Comparables ------------------------------------------------------------

  test "tiers and weights follow section and distance from row DD" do
    dd = obs("101", "DD", 200)
    assert_equal [ 1, 1.0, 200.0 ], [ dd.tier, dd.weight, dd.dd_equivalent_price ]

    gg = obs("101", "GG", 200)
    assert_equal 2, gg.tier
    assert_in_delta 0.85 * (0.85**3), gg.weight, 1e-9
    assert_equal 215.0, gg.dd_equivalent_price # 3 rows behind: +7.5%

    aa = obs("120", "AA", 200)
    assert_equal 3, aa.tier
    assert_in_delta 0.5 * (0.85**3), aa.weight, 1e-9
    assert_equal 185.0, aa.dd_equivalent_price # 3 rows in front: -7.5%

    assert_equal 4, obs("101", "MM", 150).tier
    assert_nil obs("102", "MM", 150).tier
  end

  test "primary, courtside and unknown rows are set aside" do
    assert_equal "primary", obs("120", "EE", 146.95, "standard_admission").excluded_reason
    assert_equal "courtside", obs("101", "FL2", 1093.5).excluded_reason
    assert_equal "unknown_row", obs("101", "ZZ", 150).excluded_reason
  end

  # --- Outliers ---------------------------------------------------------------

  def section(*prices)
    prices.map { |p| obs("101", "MM", p) }
  end

  test "a $1,000+ ask at 3x the section median is a placeholder; playoff-level sections aren't" do
    set = section(150, 160, 170) + [ obs("101", "KK", 1100) ]
    Market::Outliers.apply(set, @settings)
    assert_equal "placeholder", set.last.excluded_reason

    pricey = section(900, 950, 1000) + [ obs("101", "KK", 1100) ]
    Market::Outliers.apply(pricey, @settings)
    assert_nil pricey.last.excluded_reason
  end

  test "comparables far from the section's median are set aside" do
    set = section(200, 210, 220) + [ obs("120", "EE", 832), obs("101", "EE", 260) ]
    Market::Outliers.apply(set, @settings)

    assert_equal "far_above", set[-2].excluded_reason
    assert_nil set[-1].excluded_reason
  end

  test "IQR trims comparables once there are five" do
    # Section median 310: none of these is far from it, but 400 is far from
    # the other comparables.
    comps = [ 200, 205, 210, 215, 400 ].map { |p| obs("120", "DD", p) }
    Market::Outliers.apply(section(300, 310, 320) + comps, @settings)
    assert_equal [ nil, nil, nil, nil, "iqr_high" ], comps.map(&:excluded_reason)
  end

  test "a row DD listing at our own all-in price is ours" do
    set = section(150, 160, 170) + [ obs("101", "DD", 255.15), obs("101", "DD", 300) ]
    Market::Outliers.apply(set, @settings, our_all_in: 255.15)
    assert_equal [ "ours", nil ], set.last(2).map(&:excluded_reason)
  end

  # --- Valuation -------------------------------------------------------------------

  test "with no comparables the prior stands alone" do
    result = Market::Valuation.call(section(100, 200, 300), @settings, row_premium: 1.5)

    assert_not result.insufficient
    assert_equal 0, result.weight
    assert_equal 300.0, result.market # median 200 x 1.5, which the 300 ceiling allows
    assert_equal [ 270.0, 300.0, 330.0 ], [ result.competitive, result.market, result.premium ]
  end

  test "comparables pull the value toward themselves as their weight grows" do
    # Neighbor-section comparables (weight 0.5 each) leave the anchor alone:
    # prior = section median 200 x 1.25 = 250, worth 2 comparables.
    one = Market::Valuation.call(section(100, 200, 300) + [ obs("120", "DD", 280) ], @settings, row_premium: 1.25)
    assert_in_delta ((0.5 * 280) + (2 * 250)) / 2.5, one.market, 0.01

    many = section(100, 200, 300) + Array.new(6) { obs("120", "DD", 280) }
    result = Market::Valuation.call(many, @settings, row_premium: 1.25)
    assert_in_delta ((3.0 * 280) + (2 * 250)) / 5.0, result.market, 0.01
    assert_operator result.market, :>, one.market
  end

  test "row DD listings in our section also count toward its median" do
    result = Market::Valuation.call(section(100, 200, 300) + [ obs("101", "DD", 250) ], @settings, row_premium: 1.25)
    assert_equal 225.0, result.section_median
    assert_in_delta (250 + (2 * 225 * 1.25)) / 3.0, result.market, 0.01
  end

  test "market value never tops the section's highest ask or near-DD comparable" do
    result = Market::Valuation.call(section(600, 650, 700), @settings, row_premium: 1.45)
    assert_equal 700.0, result.market
    assert_equal 770.0, result.premium
  end

  test "too few listings to say anything" do
    assert Market::Valuation.call(section(100, 200), @settings, row_premium: 1.45).insufficient
  end

  # --- Fees -------------------------------------------------------------------------

  test "the buyer-fee multiplier is confirmed from the prices themselves" do
    prices = [ 160, 175, 200, 230, 250 ].map { |list| (list * 1.215).round(2) }
    detection = Market::FeeModel.detect(prices, 1.215)
    assert detection.verified
    assert_equal 1.215, detection.multiplier

    other = [ 160, 175, 200, 230, 250 ].map { |list| (list * 1.25).round(2) }
    found = Market::FeeModel.detect(other, 1.215)
    assert found.verified
    assert_in_delta 1.25, found.multiplier, 1e-9

    noise = [ 101.37, 155.91, 203.33, 267.77, 311.11 ]
    unverified = Market::FeeModel.detect(noise, 1.215)
    assert_not unverified.verified
    assert_equal 1.215, unverified.multiplier
  end

  test "list prices round by strategy" do
    assert_equal 205, Market::FeeModel.list_price(250.0, 1.215, rounding: :floor)
    assert_equal 206, Market::FeeModel.list_price(250.0, 1.215, rounding: :round)
    assert_equal 206, Market::FeeModel.list_price(250.0, 1.215, rounding: :ceil)
    assert_equal 255.15, Market::FeeModel.all_in(210, 1.215)
  end

  test "the seller fee is unknown until measured or set" do
    assert_nil Market::FeeModel.seller_fee

    AppSetting.set("pricing.seller_fee_pct", "10")
    assert_equal [ 0.1, "set in Settings" ], Market::FeeModel.seller_fee

    game = games(:current_future)
    game.listings.create!(seat_numbers: [ 1 ], platform: "ticketmaster", ask_price: 200)
    game.tickets.create!(seat_number: 1, sale_price: 170)
    assert_equal [ 0.15, "measured from 1 sale" ], Market::FeeModel.seller_fee
  end

  # --- Strategy, confidence, assessment ------------------------------------------------

  test "strategy follows time to the game, the trend and confidence" do
    pick = ->(days, change = nil, supply = nil, conf = 60) {
      Market::Strategy.choose(days: days, change_pct: change, supply_change_pct: supply, confidence: conf).first
    }
    assert_equal "market", pick.(30, nil, nil, 20)
    assert_equal "competitive", pick.(2)
    assert_equal "competitive", pick.(6)
    assert_equal "market", pick.(6, 12, -5)
    assert_equal "competitive", pick.(14, -12)
    assert_equal "competitive", pick.(14, 0, 30)
    assert_equal "premium", pick.(14, 12)
    assert_equal "market", pick.(14)
    assert_equal "premium", pick.(30)
    assert_equal "market", pick.(30, -15)
    assert_equal "market", pick.(30, nil, nil, 35)
  end

  test "confidence adds freshness at display time and caps unverified fees" do
    breakdown = { "depth" => 40, "proximity" => 15, "consistency" => 15, "anchor" => 10, "coverage" => 10 }
    captured = Time.zone.local(2026, 11, 16, 10)

    assert_equal 100, Market::Confidence.total(breakdown, captured, now: captured + 1.day)
    assert_equal 95, Market::Confidence.total(breakdown, captured, now: captured + 7.days)
    assert_equal 90, Market::Confidence.total(breakdown, captured, now: captured + 20.days)
    assert_equal 69, Market::Confidence.total(breakdown, captured, now: captured, fee_verified: false)
    assert_equal [ "High", "Medium", "Low", "Insufficient" ], [ 70, 45, 25, 24 ].map { |s| Market::Confidence.label(s) }
  end

  test "assessment compares our all-in price to market, only for a confirmed listing" do
    game = games(:current_future)
    status = ->() { game.reload.listing_status }
    assess = ->(ours, market = 250.0, conf = 60) {
      Market::Assessment.call(listing_status: status.(), our_all_in: ours, market_value: market, confidence: conf, settings: @settings)
    }

    assert_equal "needs_verification", assess.(nil)
    game.listings.create!(seat_numbers: [ 1, 2, 3 ], platform: "ticketmaster", ask_price: 210, verified_at: Time.current)
    assert_equal "competitive", assess.(255.15)
    assert_equal "overpriced", assess.(300.0)
    assert_equal "underpriced", assess.(200.0)
    assert_equal "insufficient_data", assess.(255.15, nil)
    assert_equal "insufficient_data", assess.(255.15, 250.0, 20)
    assert_equal 255.15, Market::Assessment.our_all_in(status.(), 1.215)
  end
end
