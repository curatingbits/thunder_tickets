require "test_helper"

class MoneyTest < ActionDispatch::IntegrationTest
  setup do
    @season = seasons(:current)
    @season.update!(settlement_tracked: true)
    Ticket.delete_all # the fixture sales would add their own balances
    @game = @season.games.create!(game_number: 300, game_date: Date.current - 20, opponent: teams(:rockets),
                                  cost_per_ticket: 150, parking_cost: 8.7, game_type: "regular")
    3.times { |i| @game.tickets.create!(seat_number: i + 1, sale_price: 200, sold_at: 30.days.ago) }
    _, @raw = ApiToken.generate!(name: "venmo", scopes: [ "settlements:write" ])
  end

  def post_import(key: "venmo-1", transactions:)
    post api_v1_payment_imports_path, params: { key: key, source: "finance_api", transactions: transactions },
                                      headers: { "Authorization" => "Bearer #{@raw}" }, as: :json
  end

  def tx(id, amount, memo, date: (Date.current - 10).iso8601)
    { id: id, date: date, amount: amount, name: %(Pat Partner "#{memo}"), pending: false, account: "Personal Profile" }
  end

  # --- API ------------------------------------------------------------------

  test "the import settles what it can and is idempotent by key" do
    post_import(transactions: [ tx("1", "300.00", "Thunder vs rockets #{@game.game_date.strftime('%-m/%-d')}"), tx("2", "-20", "🍿") ])
    assert_response :created
    body = response.parsed_body
    assert_equal({ "created" => 2, "matched" => 1, "ignored" => 1 }, body["stats"].slice("created", "matched", "ignored"))
    assert_equal 0, body.dig("settlement", "outstanding_cents")

    post_import(transactions: [])
    assert_response :ok
    assert_equal true, response.parsed_body["replayed"]
    assert_equal 2, PartnerPayment.count
  end

  test "the summary tells the skill what's owed and where to start reading" do
    get api_v1_settlement_summary_path, headers: { "Authorization" => "Bearer #{@raw}" }

    assert_response :success
    body = response.parsed_body
    assert_equal 30_000, body["outstanding_cents"]
    starts = [ Settlements.tracking_starts_on, Settlements.cost_share_starts_on ].min
    assert_equal [ starts, Date.current - 395 ].max.iso8601, body["window_from"]
    assert_equal [ "unpaid" ], body["games"].map { |g| g["status"] }
    assert_equal false, body["synced"]
  end

  test "before the first sync, nothing is called overdue and the balance waits" do
    sign_in
    get root_path
    assert_select "[data-settlement-tile]", text: /Waiting for the first Venmo sync/
    assert_select "[data-attention-kind='payout_overdue']", count: 0

    get money_path
    assert_select "[data-money-not-synced]"
  end

  test "a market token can't import payments" do
    _, market = ApiToken.generate!(name: "market", scopes: [ "market:write" ])
    post api_v1_payment_imports_path, params: { key: "x", transactions: [] }, headers: { "Authorization" => "Bearer #{market}" }, as: :json
    assert_response :forbidden
  end

  # --- pages ------------------------------------------------------------------

  test "the money page needs a login, then shows the balance and games" do
    get money_path
    assert_redirected_to login_path

    sign_in
    get money_path
    assert_response :success
    assert_select "[data-money-totals]", text: /owes .* \$300\.00/
    assert_select "[data-balance-game='#{@game.id}'] [data-settlement-status='unpaid']"
  end

  test "review: apply the suggestion" do
    post_import(transactions: [ tx("1", "250.00", "Thunder vs rockets #{@game.game_date.strftime('%-m/%-d')}") ])
    payment = PartnerPayment.sole
    assert_equal "needs_review", payment.status

    sign_in
    get money_path
    assert_select "[data-money-section='review']", text: /Settle: Houston Rockets \$250\.00/

    post apply_suggestion_partner_payment_path(payment)
    assert_redirected_to money_path
    assert_equal "matched", payment.reload.status
    assert_equal 25_000, SettlementAllocation.active.where(game: @game).sum(:amount_cents)
  end

  test "review: allocate by hand, undo with a reason, then ignore" do
    post_import(transactions: [ tx("1", "45.00", "Thunder ⚡") ])
    payment = PartnerPayment.sole
    assert_equal "needs_review", payment.status
    user = sign_in

    post allocate_partner_payment_path(payment), params: { game_id: @game.id, amount: "45.00", reason: "Mark said so" }
    allocation = SettlementAllocation.active.sole
    assert_equal [ "matched", 4500, user ], [ payment.reload.status, allocation.amount_cents, allocation.created_by ]

    post void_settlement_allocation_path(allocation), params: { reason: "" }
    assert allocation.reload.active?, "a void needs a reason"
    post void_settlement_allocation_path(allocation), params: { reason: "wrong game" }
    assert_not allocation.reload.active?
    assert_equal "unmatched", payment.reload.status

    post ignore_partner_payment_path(payment), params: { note: "concert tickets", category: "unrelated" }
    assert_equal [ "ignored", "unrelated", "concert tickets" ], payment.reload.slice(:status, :category, :review_note).values
    assert_equal %w[allocated voided status], payment.audit_events.order(:id).pluck(:action)
  end

  test "a payment entered by hand is matched like any other" do
    sign_in
    post partner_payments_path, params: { partner_payment: { occurred_on: Date.current.iso8601, direction: "incoming",
                                                             amount: "300", memo: "Thunder vs rockets #{@game.game_date.strftime('%-m/%-d')}" } }
    payment = PartnerPayment.sole
    assert_redirected_to partner_payment_path(payment)
    assert_equal [ "manual", "matched" ], [ payment.source, payment.status ]
  end

  test "home shows the payout tile, and attention flags review and overdue payouts" do
    post_import(transactions: [ tx("1", "77.00", "Thunder?") ])
    sign_in
    get root_path

    assert_select "[data-settlement-tile]", text: /owes/
    assert_select "[data-attention-kind='settlement_review']"
    assert_select "[data-attention-kind='payout_overdue']", text: /owes \$300\.00 for 1 game/
  end

  test "home's Payouts lists the three latest payments under the games not fully paid" do
    post_import(transactions: [ tx("1", "100.00", "Thunder one", date: (Date.current - 12).iso8601),
                                tx("2", "100.00", "Thunder two", date: (Date.current - 9).iso8601),
                                tx("3", "-20", "🍿", date: (Date.current - 2).iso8601),
                                tx("4", "100.00", "Thunder three", date: (Date.current - 6).iso8601),
                                tx("5", "100.00", "Thunder four", date: (Date.current - 3).iso8601) ])
    assert_equal "ignored", PartnerPayment.find_by!(external_id: "3").status
    sign_in
    get root_path

    assert_select "[data-dashboard-section='payouts'] [data-settlement-tile]" do
      memos = css_select("[data-recent-payments] li").map { |li| li.text[/“(.+)”/, 1] }
      assert_equal [ "Thunder four", "Thunder three", "Thunder two" ], memos, "newest first, leaving out the one set aside"
    end
    tile = css_select("[data-settlement-tile]").first.to_html
    assert_operator tile.index("not fully paid"), :<, tile.index("data-recent-payments")
  end

  test "the Money tab tracks Duggan's half of the season invoice" do
    @season.update!(year: "2026-27", total_season_cost: 20_842.80)
    post_import(transactions: [ tx("c1", "-1042.14", "Thunder 26/27", date: "2026-08-18") ])

    sign_in
    get money_path
    assert_select "[data-money-section='cost-share']", text: /1,042\.14.*of.*10,421\.40.*paid/m
    assert_select "[data-cost-share-remaining]", text: /\$9,379\.26 left/
  end

  test "a sale's payout can be marked as having gone to the owner" do
    sign_in
    ticket = @game.tickets.first
    patch game_ticket_path(@game, ticket), params: { ticket: { payout_received_by: "owner" } }
    assert_equal "owner", ticket.reload.payout_received_by
    assert_equal 10_000, Settlements::Ledger.new.for_game(@game).expected_cents
  end
end
