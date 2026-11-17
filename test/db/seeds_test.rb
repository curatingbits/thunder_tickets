require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  def empty_database
    [ ListingEvent, Ticket, Listing, MarketPrice, Game, Buyer, Season, Team, User ].each(&:delete_all)
  end

  def load_seeds
    capture_io { Rails.application.load_seed }
  end

  def counts
    [ Team, User, Season, Game, Ticket, Buyer ].map(&:count)
  end

  test "an empty database gets teams, a sign-in and a sample season" do
    empty_database
    load_seeds

    assert_equal 29, Team.count
    assert User.active.find_by(email: "admin@example.com")&.authenticate("password")

    season = Season.sole
    assert season.is_current?
    assert_equal 3, season.num_seats
    assert_equal 42, season.games.count, "2 preseason + 40 regular season home games"

    tickets = Ticket.all
    assert tickets.any?
    assert tickets.all? { |t| t.section == "101" && t.row == "DD" }
    assert tickets.all? { |t| t.sold_at <= Time.current }
    assert tickets.any? { |t| t.buyer.nil? } && tickets.any?(&:buyer)
  end

  test "running the seeds again adds nothing" do
    empty_database
    load_seeds

    before = counts
    load_seeds

    assert_equal before, counts
  end

  test "a database with seasons keeps its data and only gains missing teams" do
    seasons, games, tickets, users = Season.count, Game.count, Ticket.count, User.count

    load_seeds

    assert_equal [ seasons, games, tickets, users ], [ Season.count, Game.count, Ticket.count, User.count ]
    assert_equal 29, Team.count
  end

  test "production gets teams and nothing else" do
    empty_database
    original_env = Rails.env
    Rails.env = "production"

    load_seeds

    assert_equal 29, Team.count
    assert_equal [ 0, 0, 0 ], [ User.count, Season.count, Ticket.count ]
  ensure
    Rails.env = original_env
  end
end
