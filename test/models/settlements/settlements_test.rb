require "test_helper"

# Scenarios modeled on the real 2026-27 memos (names and amounts made up).
class SettlementsTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:current)
    @season.update!(settlement_tracked: true, partner_split_pct: 50)
    seasons(:past_season).update!(settlement_tracked: false)
    @teams = %w[Atlanta\ Hawks Brooklyn\ Nets Charlotte\ Hornets Minnesota\ Timberwolves Cleveland\ Cavaliers Indiana\ Pacers Boston\ Celtics]
             .zip(%w[ATL BKN CHA MIN CLE IND BOS]).to_h { |name, abbr| [ abbr, Team.find_or_create_by!(name: name) { |t| t.abbreviation = abbr } ] }
    @number = 200
  end

  def game(abbr, date, sold: [], type: "regular")
    g = @season.games.create!(game_number: @number += 1, game_date: Date.iso8601(date), opponent: @teams.fetch(abbr),
                              cost_per_ticket: 150, parking_cost: 8.7, game_type: type)
    sold.each_with_index { |price, i| g.tickets.create!(seat_number: i + 1, sale_price: price) }
    g
  end

  def import(*rows)
    run = ImportRun.create!(kind: "payment_sync", source: "finance_api", key: "t-#{SecureRandom.hex(3)}", status: "completed",
                            started_at: Time.current)
    txs = rows.map.with_index do |(date, amount, memo), i|
      { "id" => "tx-#{SecureRandom.hex(4)}-#{i}", "date" => date, "amount" => amount.to_s, "pending" => false,
        "name" => "Pat Partner \"#{memo}\"", "account" => "Personal Profile" }
    end
    Settlements::Importer.new(run: run, transactions: txs).call
  end

  def balance(g) = Settlements::Ledger.new.for_game(g)
  def payment(memo) = PartnerPayment.find_by!(memo: memo)

  # --- parsing ------------------------------------------------------------

  test "the memo splits into games: teams, dates, hints and the buyer" do
    parsed = Settlements::MemoParser.parse(%(Pat Partner "Thunder vs hawks 11/18 AND Thunder vs nets 12/2 ⚡⚡⚡"), season: nil)
    assert_equal "Pat Partner", parsed.payer
    assert parsed.thunder
    assert_equal [ [ @teams["ATL"].id ], [ @teams["BKN"].id ] ], parsed.references.map(&:team_ids)
    assert_equal [ [ 11, 18 ], [ 12, 2 ] ], parsed.references.map { |r| [ r.date.month, r.date.day ] }

    ref = Settlements::MemoParser.parse(%(X "10/25 thunder vs twolves to Kolton, half of 3rd ticket")).references.first
    assert_equal [ @teams["MIN"].id ], ref.team_ids
    assert_equal "Kolton", ref.buyer
    assert ref.partial
    assert Settlements::MemoParser.parse(%(X "Thunder vs pacers preseason")).references.first.preseason
  end

  test "whole words only, and scores or season years aren't dates" do
    hornets = Settlements::MemoParser.parse(%(X "Thunder vs Hornets")).references.first
    assert_equal [ @teams["CHA"].id ], hornets.team_ids
    assert_nil Settlements::MemoParser.parse(%(X "Thunder up 2-0")).references.first.date
    assert_nil Settlements::MemoParser.parse(%(X "Thunder 26/27")).references.first.date
  end

  test "season installments are cost share; games are settlements; the rest unrelated" do
    classify = ->(direction, memo) {
      Settlements::PaymentClassifier.call(PartnerPayment.new(direction: direction), Settlements::MemoParser.parse(%(X "#{memo}")))
    }
    assert_equal "cost_share", classify.("outgoing", "Thunder season tickets payment 26/27 ⚡")
    assert_equal "cost_share", classify.("outgoing", "Thunder 2026-2027")
    assert_equal "settlement", classify.("outgoing", "Celtics")
    assert_equal "unrelated", classify.("outgoing", "🥃")
    assert_equal "settlement", classify.("incoming", "Thunder vs Suns 10/26 ⚡️")
    assert_equal "unknown", classify.("incoming", "⛳️⛳️")
  end

  # --- ledger ---------------------------------------------------------------

  test "the partner owes half the payout, rounded half-up per game like Venmo" do
    g = game("MIN", "2026-11-25", sold: [ 289.75, 289.75, 289.75 ])
    assert_equal 43_463, balance(g).expected_cents # half of $869.25
    assert_equal :unpaid, balance(g).status
  end

  test "a payout that went to the owner flips the direction" do
    g = game("ATL", "2026-11-18", sold: [ 200, 200 ])
    g.tickets.first.update!(payout_received_by: "owner")
    assert_equal 0, balance(g).expected_cents
    g.tickets.last.update!(payout_received_by: "owner")
    assert_equal(-20_000, balance(g).expected_cents)
  end

  test "the sync window reaches back to game payments or season installments, whichever starts first" do
    @season.update!(year: "2026-27")
    game("ATL", "2026-10-07")
    first = Game.joins(:season).where(seasons: { settlement_tracked: true }).minimum(:game_date)
    assert_equal first - 90, Settlements.tracking_starts_on
    assert_equal Date.new(2026, 3, 1), Settlements.cost_share_starts_on

    travel_to(Date.new(2026, 11, 16)) do
      assert_equal [ [ first - 90, Date.new(2026, 3, 1) ].min, Date.new(2026, 11, 16) - 395 ].max, Settlements::Summary.new.window_from
    end
    travel_to(Date.new(2028, 6, 1)) { assert_equal Date.new(2028, 6, 1) - 395, Settlements::Summary.new.window_from }
  end

  test "from before tracking began, only season installments are imported" do
    start = Settlements.tracking_starts_on
    summary = import([ (start - 10).iso8601, "-1042.14", "Thunder 26/27" ],
                     [ (start - 10).iso8601, "150.00", "Thunder vs hawks 4/2" ],
                     [ (start - 5).iso8601, "-20.00", "🍿" ],
                     [ (start + 5).iso8601, "-20.00", "🍿 again" ])

    assert_equal 2, summary.out_of_scope
    assert_equal [ "Thunder 26/27", "🍿 again" ], PartnerPayment.order(:occurred_on).pluck(:memo)
  end

  test "season installments count toward the season they name, or the spring they fall in" do
    @season.update!(year: "2026-27", total_season_cost: 20_842.80)
    import([ "2026-04-21", "-1042.14", "April 2026 payment - 2026/2027 Thunder Season tickets" ],
           [ "2026-05-15", "-1042.14", "26/27 Thunder" ],
           [ "2026-07-15", "-1042.14", "Thunder season tickets payment ⚡" ],
           [ "2026-08-18", "-1042.14", "Thunder 25/26" ],
           [ "2026-08-20", "-60.00", "🍿" ])

    share = Settlements::CostShare.for(@season)
    assert_equal [ 2_084_280, 1_042_140, 312_642, 729_498, 30 ],
                 [ share.invoice_cents, share.share_cents, share.paid_cents, share.remaining_cents, share.paid_pct ]
    assert_equal %w[2026-04-21 2026-05-15 2026-07-15], share.payments.map { |p| p.occurred_on.iso8601 }
    assert_nil Settlements::CostShare.for(seasons(:past_season))
  end

  # --- matching ---------------------------------------------------------------

  test "an exact payment naming the game and date settles automatically" do
    g = game("MIN", "2026-11-25", sold: [ 289.75, 289.75, 289.75 ])
    import([ "2026-11-11", "434.63", "Thunder vs Twolves 11/25 ⚡" ])

    p = payment("Thunder vs Twolves 11/25 ⚡")
    assert_equal [ "matched", "settlement" ], [ p.status, p.category ]
    assert_operator p.match_confidence, :>=, 85
    assert_equal :paid, balance(g).status
  end

  test "one payment can settle two games" do
    hawks = game("ATL", "2026-11-18", sold: [ 200, 200, 200 ])
    nets = game("BKN", "2026-12-02", sold: [ 200, 200, 200 ])
    import([ "2026-11-06", "600.00", "Thunder vs hawks 11/18 AND Thunder vs nets 12/2 ⚡⚡⚡" ])

    assert_equal [ 30_000, 30_000 ], [ hawks, nets ].map { |g| balance(g).allocated_cents }
    assert_equal "matched", payment("Thunder vs hawks 11/18 AND Thunder vs nets 12/2 ⚡⚡⚡").status
  end

  test "two partial payments can settle one game, when the memos say so" do
    g = game("CLE", "2026-11-04", sold: [ 155, 155 ])
    import([ "2026-11-05", "77.50", "Thunder vs Cavs 11/4 half of 1st ticket" ],
           [ "2026-11-11", "77.50", "Thunder vs Cavs 11/4 ⚡ half of 2nd ticket" ])

    assert_equal 15_500, balance(g).allocated_cents
    assert_equal :paid, balance(g).status
  end

  test "less than owed with no note, or more than owed, goes to review with a suggestion" do
    short = game("ATL", "2026-11-18", sold: [ 200, 200, 200 ])
    import([ "2026-11-20", "250.00", "Thunder vs hawks 11/18" ])
    p = payment("Thunder vs hawks 11/18")
    assert_equal "needs_review", p.status
    assert_equal [ { "game_id" => short.id, "cents" => 25_000 } ], p.match_details["suggestion"]
    assert_equal :needs_review, balance(short).status

    game("BKN", "2026-12-02", sold: [ 100 ])
    import([ "2026-12-03", "80.00", "Thunder vs nets 12/2" ])
    assert_equal "needs_review", payment("Thunder vs nets 12/2").status
  end

  test "two games the memo could mean, with nothing to tell them apart, go to review" do
    game("ATL", "2026-11-18", sold: [ 200, 200 ])
    game("ATL", "2026-12-20", sold: [ 200, 200 ])
    import([ "2026-11-30", "200.00", "Thunder vs hawks" ])

    assert_equal "needs_review", payment("Thunder vs hawks").status
  end

  test "money between friends is ignored; an unexplained exact amount is suggested" do
    game("ATL", "2026-11-18", sold: [ 50, 50 ])
    import([ "2026-11-01", "20.00", "⛳️⛳️" ], [ "2026-11-19", "50.00", "🙂" ])

    assert_equal [ "ignored", "unrelated" ], payment("⛳️⛳️").slice(:status, :category).values
    smiley = payment("🙂")
    assert_equal "needs_review", smiley.status
    assert_equal 1, smiley.match_details["suggestion"].size
  end

  test "outgoing payments are never settled automatically" do
    import([ "2026-08-18", "-1042.14", "Thunder 26/27" ], [ "2026-10-20", "-200", "Celtics" ])

    assert_equal [ "ignored", "cost_share" ], payment("Thunder 26/27").slice(:status, :category).values
    assert_equal [ "needs_review", "settlement" ], payment("Celtics").slice(:status, :category).values
  end

  test "a payment that arrives before its sale is entered settles once it is" do
    g = game("IND", "2026-10-13", type: "preseason")
    import([ "2026-10-07", "156.75", "Thunder vs pacers preseason ⚡️" ])
    p = payment("Thunder vs pacers preseason ⚡️")
    assert_equal "unmatched", p.status
    assert_equal "for the sale to be recorded", p.match_details["waiting"]

    3.times { |i| g.tickets.create!(seat_number: i + 1, sale_price: 104.50) }
    Settlements::Matcher.new.run
    assert_equal "matched", p.reload.status
    assert_equal :paid, balance(g).status
  end

  # --- imports ---------------------------------------------------------------

  test "re-importing is idempotent; a changed transaction goes to review; pending is skipped" do
    game("MIN", "2026-11-25", sold: [ 289.75, 289.75, 289.75 ])
    run = ImportRun.create!(kind: "payment_sync", source: "finance_api", key: "a", status: "completed", started_at: Time.current)
    tx = { "id" => "42", "date" => "2026-11-11", "amount" => "434.63", "name" => %(P "Thunder vs Twolves 11/25"), "pending" => false }
    pending = { "id" => "43", "date" => "2026-11-12", "amount" => "10", "name" => %(P "x"), "pending" => true }

    first = Settlements::Importer.new(run: run, transactions: [ tx, pending ]).call
    assert_equal [ 1, 1, 1 ], [ first.created, first.skipped_pending, first.matched ]

    again = Settlements::Importer.new(run: run, transactions: [ tx ]).call
    assert_equal [ 0, 1 ], [ again.created, again.unchanged ]

    changed = Settlements::Importer.new(run: run, transactions: [ tx.merge("amount" => "400.00") ]).call
    assert_equal 1, changed.changed
    p = PartnerPayment.find_by!(external_id: "42")
    assert_equal [ "needs_review", 43_463 ], [ p.status, p.amount_cents ]
    assert_equal "source_changed", p.audit_events.last.action
  end

  test "the same payment under two ids is flagged as a duplicate" do
    game("MIN", "2026-11-25", sold: [ 289.75, 289.75, 289.75 ])
    import([ "2026-11-11", "434.63", "Thunder vs Twolves 11/25 ⚡" ], [ "2026-11-11", "434.63", "Thunder vs Twolves 11/25 ⚡" ])

    twins = PartnerPayment.where(memo: "Thunder vs Twolves 11/25 ⚡").order(:id)
    assert_equal [ "matched", "needs_review" ], twins.map(&:status)
    assert_equal twins.first, twins.last.possible_duplicate_of
  end

  # --- corrections ---------------------------------------------------------------

  test "voiding keeps the record, frees the money, and is audited; payments can't be spent twice" do
    hawks = game("ATL", "2026-11-18", sold: [ 200, 200, 200 ])
    nets = game("BKN", "2026-12-02", sold: [ 200, 200, 200 ])
    import([ "2026-11-20", "300.00", "Thunder vs hawks 11/18" ])
    p = payment("Thunder vs hawks 11/18")
    allocation = p.allocations.sole
    user = users(:admin)

    assert_raises(Settlements::Allocator::Error) { Settlements::Allocator.void!(allocation, reason: "", user: user) }
    Settlements::Allocator.void!(allocation, reason: "Mark meant the Nets game", user: user)
    assert_equal "unmatched", p.reload.status
    assert_equal 0, balance(hawks).allocated_cents

    Settlements::Allocator.allocate!(p, nets, 30_000, method: "manual", reason: "per Mark", user: user, replaces: allocation)
    assert_raises(Settlements::Allocator::Error) do
      Settlements::Allocator.allocate!(p, hawks, 1, method: "manual", reason: "again", user: user)
    end
    assert_equal :paid, balance(nets).status
    assert_equal 2, SettlementAllocation.where(partner_payment: p).count
    assert_equal %w[allocated voided allocated], p.audit_events.order(:id).pluck(:action)
  end
end
