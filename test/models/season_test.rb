require "test_helper"

class SeasonTest < ActiveSupport::TestCase
  setup do
    @current = seasons(:current)   # active: has a future game
    @past = seasons(:past_season)  # complete: all games in the past
  end

  # --- Status detection -------------------------------------------------

  test "season with a future game is active, not complete" do
    assert @current.active?
    assert_not @current.complete?
    assert_equal :active, @current.status
  end

  test "season with only past games is complete" do
    assert @past.complete?
    assert_not @past.active?
    assert_equal :complete, @past.status
  end

  test "season with no games is active (nothing to recap)" do
    empty = Season.create!(year: "1999-00", num_seats: 1, is_current: false)
    assert empty.active?
    assert_not empty.complete?
  end

  test "last_game_date returns the latest game date" do
    assert_equal games(:past_playoff).game_date, @past.last_game_date
  end

  # --- Game-type breakdown ----------------------------------------------

  test "profit_by_game_type returns only present types in order" do
    breakdown = @past.profit_by_game_type
    assert_equal %w[regular playoff], breakdown.map { |r| r[:type] }
  end

  test "profit_by_game_type lists preseason first and labels it" do
    @past.games.create!(
      game_number: 99,
      game_date: 9.months.ago.to_date,
      opponent: teams(:nuggets),
      cost_per_ticket: 50,
      parking_cost: 10,
      game_type: "preseason"
    )

    breakdown = @past.reload.profit_by_game_type
    assert_equal %w[preseason regular playoff], breakdown.map { |r| r[:type] }
    assert_equal "Preseason", breakdown.first[:label]
    assert_in_delta @past.total_profit, breakdown.sum { |r| r[:profit] }, 0.01
  end

  test "profit_by_game_type rows reconcile to total_profit" do
    breakdown = @past.profit_by_game_type
    assert_in_delta @past.total_profit, breakdown.sum { |r| r[:profit] }, 0.01
  end

  test "profit_by_game_type computes per-type figures" do
    regular = @past.profit_by_game_type.find { |r| r[:type] == "regular" }
    assert_equal 1, regular[:games_count]
    assert_in_delta 220, regular[:cost], 0.01
    assert_in_delta 300, regular[:revenue], 0.01
    assert_in_delta 80, regular[:profit], 0.01
    assert_equal 2, regular[:tickets_sold]
  end

  # --- Monthly financials (cumulative) ----------------------------------

  test "monthly_financials is empty for a season with no games" do
    empty = Season.create!(year: "1998-99", num_seats: 1, is_current: false)
    assert_equal [], empty.monthly_financials
  end

  test "monthly_financials cumulative revenue ends at total_revenue" do
    series = @past.monthly_financials
    assert series.any?
    assert_in_delta @past.total_revenue, series.last[:cumulative_revenue], 0.01
    assert_in_delta @past.total_cost, series.last[:cumulative_cost], 0.01
  end

  test "monthly_financials is sorted ascending by month" do
    months = @past.monthly_financials.map { |p| p[:month] }
    assert_equal months.sort, months
  end

  # --- Recap / write-off metrics ----------------------------------------

  test "unsold_tickets_count counts unsold seats" do
    # past season: 4 seats available, 3 sold => 1 unsold
    assert_equal 1, @past.unsold_tickets_count
  end

  test "unsold_inventory_cost is the sunk ticket cost of unsold seats" do
    # 1 unsold playoff seat * 150 cost_per_ticket
    assert_in_delta 150, @past.unsold_inventory_cost, 0.01
  end

  test "final aliases mirror total_profit and roi" do
    assert_equal @past.total_profit, @past.final_net_profit
    assert_equal @past.roi, @past.final_roi
  end
end
