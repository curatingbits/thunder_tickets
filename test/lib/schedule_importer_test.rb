require "test_helper"
require Rails.root.join("lib/schedule_importer")

class ScheduleImporterTest < ActiveSupport::TestCase
  # Two home games and one away game, shaped like the ESPN team-schedule payload.
  FIXTURE = {
    "events" => [
      {
        "date" => "2026-10-23T01:30Z",
        "competitions" => [{
          "notes" => [],
          "competitors" => [
            { "id" => "25", "homeAway" => "home", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "7",  "homeAway" => "away", "team" => { "displayName" => "Denver Nuggets" } }
          ]
        }]
      },
      {
        "date" => "2026-10-26T00:00Z",
        "competitions" => [{
          "notes" => [ { "type" => "event", "headline" => "NBA Cup - Group Play" } ],
          "competitors" => [
            { "id" => "25", "homeAway" => "home", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "12", "homeAway" => "away", "team" => { "displayName" => "LA Clippers" } }
          ]
        }]
      },
      {
        "date" => "2026-10-28T00:00Z",
        "competitions" => [{
          "notes" => [],
          "competitors" => [
            { "id" => "25", "homeAway" => "away", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "10", "homeAway" => "home", "team" => { "displayName" => "Houston Rockets" } }
          ]
        }]
      }
    ]
  }.freeze

  def setup
    # Parallel test workers each get their own file; a shared path races.
    @path = Rails.root.join("tmp", "schedule_importer_test_#{Process.pid}_#{object_id}.json").to_s
    File.write(@path, JSON.generate(FIXTURE))
  end

  def teardown
    File.delete(@path) if File.exist?(@path)
  end

  def importer(**overrides)
    ScheduleImporter.new(**{
      season_year: "2099-00",
      source_path: @path,
      total_cost: 1_000.00,
      parking_cost: 10.00,
      num_seats: 2,
      seat_section: "101"
    }.merge(overrides))
  end

  test "selects only home games, in chronological order" do
    games = importer.home_games

    assert_equal 2, games.size
    assert_equal [ "Denver Nuggets", "LA Clippers" ], games.map { |g| g[:opponent] }
    assert_equal [ false, true ], games.map { |g| g[:nba_cup] }
  end

  test "converts tipoff to Central time before taking the date" do
    # 2026-10-23T01:30Z is still Oct 22 in Oklahoma City.
    assert_equal Date.new(2026, 10, 22), importer.home_games.first[:date]
  end

  test "derives cost per ticket by backing parking out of the season total" do
    # (1000 - 10*2) / (2 seats * 2 games) = 245.00
    assert_equal BigDecimal("245.00"), importer.derive_cost_per_ticket(2)
  end

  test "billed_games overrides the imported game count when the invoice covers more" do
    # (1000 - 10*4) / (2 seats * 4 games) = 120.00
    assert_equal BigDecimal("120.00"), importer(billed_games: 4).derive_cost_per_ticket(2)
  end

  test "raises when parking alone exhausts the season total" do
    assert_raises(ScheduleImporter::Error) do
      importer(total_cost: 15.00).derive_cost_per_ticket(2)
    end
  end

  test "creates the season and its home games" do
    result = importer.call

    assert_equal 2, result.created
    assert_equal 0, result.updated

    season = result.season
    assert_equal "2099-00", season.year
    assert_equal "101", season.seat_section
    assert season.is_current?

    games = season.games.order(:game_number)
    assert_equal [ 1, 2 ], games.map(&:game_number)
    assert_equal [ "Denver Nuggets", "Los Angeles Clippers" ], games.map { |g| g.opponent.name }
    assert games.all? { |g| g.cost_per_ticket == BigDecimal("245.00") }
    assert games.all? { |g| g.game_type == "regular" }
  end

  test "re-running updates games in place and preserves tickets" do
    season = importer.call.season
    game = season.games.order(:game_number).first
    Ticket.create!(game: game, seat_number: 1, sale_price: 300, section: "101")

    result = importer(total_cost: 2_000.00).call

    assert_equal 0, result.created
    assert_equal 2, result.updated
    assert_equal 2, result.season.games.count
    assert_equal 1, game.reload.tickets.count
    assert_equal BigDecimal("495.00"), game.cost_per_ticket
  end

  test "maps ESPN display names onto this app's team records" do
    clippers = importer.call.season.games.order(:game_number).last
    assert_equal "Los Angeles Clippers", clippers.opponent.name
  end

  test "marking a season current clears the flag on other seasons" do
    other = Season.create!(year: "2098-99", num_seats: 3, is_current: true)

    importer.call

    refute other.reload.is_current?
  end

  test "raises when the payload has no home games" do
    File.write(@path, JSON.generate({ "events" => [ FIXTURE["events"].last ] }))

    assert_raises(ScheduleImporter::Error) { importer.call }
  end

  test "raises when an opponent has no matching Team record" do
    payload = Marshal.load(Marshal.dump(FIXTURE))
    payload["events"].first["competitions"].first["competitors"].last["team"]["displayName"] = "Seattle SuperSonics"
    File.write(@path, JSON.generate(payload))

    assert_raises(ScheduleImporter::Error) { importer.call }
  end

  test "a failed import leaves no partial season behind" do
    payload = Marshal.load(Marshal.dump(FIXTURE))
    payload["events"].last["competitions"].first["competitors"].first["homeAway"] = "home"
    payload["events"].last["competitions"].first["competitors"].last["team"]["displayName"] = "Seattle SuperSonics"
    File.write(@path, JSON.generate(payload))

    assert_raises(ScheduleImporter::Error) { importer.call }
    assert_nil Season.find_by(year: "2099-00")
  end
end
