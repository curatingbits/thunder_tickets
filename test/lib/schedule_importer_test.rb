require "test_helper"
require Rails.root.join("lib/schedule_importer")

class ScheduleImporterTest < ActiveSupport::TestCase
  # Regular season: two home games (Paycom) and one away game.
  REGULAR = {
    "events" => [
      {
        "date" => "2026-10-23T01:30Z",
        "seasonType" => { "abbreviation" => "reg" },
        "competitions" => [ {
          "notes" => [],
          "venue" => { "fullName" => "Paycom Center" },
          "competitors" => [
            { "id" => "25", "homeAway" => "home", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "7",  "homeAway" => "away", "team" => { "displayName" => "Denver Nuggets" } }
          ]
        } ]
      },
      {
        "date" => "2026-10-26T00:00Z",
        "seasonType" => { "abbreviation" => "reg" },
        "competitions" => [ {
          "notes" => [ { "type" => "event", "headline" => "NBA Cup - Group Play" } ],
          "venue" => { "fullName" => "Paycom Center" },
          "competitors" => [
            { "id" => "25", "homeAway" => "home", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "12", "homeAway" => "away", "team" => { "displayName" => "LA Clippers" } }
          ]
        } ]
      },
      {
        "date" => "2026-10-28T00:00Z",
        "seasonType" => { "abbreviation" => "reg" },
        "competitions" => [ {
          "notes" => [],
          "venue" => { "fullName" => "Toyota Center" },
          "competitors" => [
            { "id" => "25", "homeAway" => "away", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "10", "homeAway" => "home", "team" => { "displayName" => "Houston Rockets" } }
          ]
        } ]
      }
    ]
  }.freeze

  # Preseason: one home game at Paycom, one "home" game in Tulsa that
  # season-ticket holders do not receive.
  PRESEASON = {
    "events" => [
      {
        "date" => "2026-10-07T00:00Z",
        "seasonType" => { "abbreviation" => "pre" },
        "competitions" => [ {
          "notes" => [],
          "venue" => { "fullName" => "BOK Center" },
          "competitors" => [
            { "id" => "25", "homeAway" => "home", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "3",  "homeAway" => "away", "team" => { "displayName" => "Dallas Mavericks" } }
          ]
        } ]
      },
      {
        "date" => "2026-10-08T00:00Z",
        "seasonType" => { "abbreviation" => "pre" },
        "competitions" => [ {
          "notes" => [],
          "venue" => { "fullName" => "Paycom Center" },
          "competitors" => [
            { "id" => "25", "homeAway" => "home", "team" => { "displayName" => "Oklahoma City Thunder" } },
            { "id" => "10", "homeAway" => "away", "team" => { "displayName" => "Houston Rockets" } }
          ]
        } ]
      }
    ]
  }.freeze

  def setup
    # Parallel test workers each get their own files; a shared path races.
    stem = "#{Process.pid}_#{object_id}"
    @regular_path = Rails.root.join("tmp", "sched_reg_#{stem}.json").to_s
    @preseason_path = Rails.root.join("tmp", "sched_pre_#{stem}.json").to_s
    File.write(@regular_path, JSON.generate(REGULAR))
    File.write(@preseason_path, JSON.generate(PRESEASON))
  end

  def teardown
    [ @regular_path, @preseason_path ].each { |p| File.delete(p) if File.exist?(p) }
  end

  def importer(paths: [ @regular_path ], **overrides)
    ScheduleImporter.new(**{
      season_year: "2099-00",
      source_paths: paths,
      total_cost: 1_000.00,
      parking_cost: 10.00,
      num_seats: 2,
      seat_section: "101"
    }.merge(overrides))
  end

  def both_paths
    [ @preseason_path, @regular_path ]
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

  test "reconciled_total reports what the rounded per-ticket cost re-totals to" do
    # 245.00 * 2 seats * 2 games + 10 * 2 = 1000.00, exact here.
    assert_equal BigDecimal("1000.00"), importer.reconciled_total(2)
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

  test "stores each game's tipoff time" do
    games = importer.call.season.games.order(:game_number)

    assert_equal Time.utc(2026, 10, 23, 1, 30), games.first.tipoff_at
    assert_equal "2026-10-22 20:30 CDT", games.first.tipoff_at.strftime("%Y-%m-%d %H:%M %Z")
  end

  test "importing needs the cost arguments" do
    error = assert_raises(ScheduleImporter::Error) do
      ScheduleImporter.new(season_year: "2099-00", source_paths: [ @regular_path ]).call
    end
    assert_match(/required to price games/, error.message)
  end

  test "backfill_tipoffs fills blank tipoffs and leaves set ones alone" do
    season = importer.call.season
    nuggets, clippers = season.games.order(:game_number).to_a
    nuggets.update_columns(tipoff_at: nil)
    corrected = Time.utc(2026, 10, 26, 1, 0)
    clippers.update_columns(tipoff_at: corrected)

    result = ScheduleImporter.new(season_year: "2099-00", source_paths: [ @regular_path ]).backfill_tipoffs

    assert_equal 1, result.filled
    assert_equal 1, result.already_set
    assert_empty result.unmatched
    assert_equal Time.utc(2026, 10, 23, 1, 30), nuggets.reload.tipoff_at
    assert_equal corrected, clippers.reload.tipoff_at
  end

  test "backfill_tipoffs reports schedule games it can't find" do
    season = importer.call.season
    season.games.order(:game_number).first.update_columns(game_date: Date.new(2026, 10, 21), tipoff_at: nil)

    result = ScheduleImporter.new(season_year: "2099-00", source_paths: [ @regular_path ]).backfill_tipoffs

    assert_equal 0, result.filled
    assert_equal [ "Denver Nuggets" ], result.unmatched.map { |g| g[:opponent] }
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
    File.write(@regular_path, JSON.generate({ "events" => [ REGULAR["events"].last ] }))

    assert_raises(ScheduleImporter::Error) { importer.call }
  end

  test "raises when an opponent has no matching Team record" do
    payload = Marshal.load(Marshal.dump(REGULAR))
    payload["events"].first["competitions"].first["competitors"].last["team"]["displayName"] = "Seattle SuperSonics"
    File.write(@regular_path, JSON.generate(payload))

    assert_raises(ScheduleImporter::Error) { importer.call }
  end

  test "a failed import leaves no partial season behind" do
    payload = Marshal.load(Marshal.dump(REGULAR))
    # Make the third game a Paycom home game (so it survives the venue filter)
    # against a team this app doesn't have a record for.
    third = payload["events"].last["competitions"].first
    third["venue"]["fullName"] = "Paycom Center"
    third["competitors"].first["homeAway"] = "home"
    third["competitors"].last["team"]["displayName"] = "Seattle SuperSonics"
    File.write(@regular_path, JSON.generate(payload))

    assert_raises(ScheduleImporter::Error) { importer.call }
    assert_nil Season.find_by(year: "2099-00")
  end

  test "raises on an unrecognised seasonType rather than guessing" do
    payload = Marshal.load(Marshal.dump(REGULAR))
    payload["events"].first["seasonType"] = { "abbreviation" => "post" }
    File.write(@regular_path, JSON.generate(payload))

    assert_raises(ScheduleImporter::Error) { importer.home_games }
  end

  # ---- preseason ----

  test "preseason is excluded unless its source file is supplied" do
    assert importer.home_games.none? { |g| g[:game_type] == "preseason" }
  end

  test "combines preseason and regular season, preseason first" do
    games = importer(paths: both_paths).home_games

    assert_equal 3, games.size
    assert_equal %w[preseason regular regular], games.map { |g| g[:game_type] }
    assert_equal [ "Houston Rockets", "Denver Nuggets", "LA Clippers" ], games.map { |g| g[:opponent] }
  end

  test "home games at another venue are excluded" do
    games = importer(paths: both_paths).home_games

    refute games.any? { |g| g[:venue] == "BOK Center" }
    assert games.all? { |g| g[:venue] == "Paycom Center" }
  end

  test "excluded_home_games reports what was dropped and why" do
    excluded = importer(paths: both_paths).excluded_home_games

    assert_equal 1, excluded.size
    assert_equal "BOK Center", excluded.first[:venue]
    assert_equal "Dallas Mavericks", excluded.first[:opponent]
  end

  test "preseason games spread the invoice across more games" do
    # regular only: (1000 - 10*2) / (2 * 2) = 245.00
    # with preseason: (1000 - 10*3) / (2 * 3) = 161.67
    assert_equal BigDecimal("245.00"), importer.derive_cost_per_ticket(2)
    assert_equal BigDecimal("161.67"), importer(paths: both_paths).derive_cost_per_ticket(3)
  end

  test "persists preseason games with the preseason type and sequential numbers" do
    result = importer(paths: both_paths).call
    games = result.season.games.order(:game_number)

    assert_equal 3, result.created
    assert_equal [ 1, 2, 3 ], games.map(&:game_number)
    assert_equal %w[preseason regular regular], games.map(&:game_type)
    assert games.first.preseason?
  end

  test "NBA Cup group games are labelled with their round" do
    games = importer(paths: both_paths).call.season.games.order(:game_number)
    cup = games.find { |g| g.opponent.name == "Los Angeles Clippers" }

    assert_equal "Group Play", cup.playoff_round
    assert_nil games.first.playoff_round
  end

  test "raises when a source file is missing" do
    assert_raises(ScheduleImporter::Error) do
      importer(paths: [ Rails.root.join("tmp", "definitely_absent.json").to_s ]).home_games
    end
  end
end
