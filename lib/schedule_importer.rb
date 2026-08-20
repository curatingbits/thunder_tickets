# Imports OKC home games for a season from a cached ESPN team-schedule JSON file.
#
# The JSON is the payload of:
#   https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams/okc/schedule?season=<end_year>&seasontype=2
#
# It is cached under db/schedules/<year>.json rather than fetched at runtime:
# ESPN's edge (Akamai) rejects non-browser clients with 403, so an unattended
# HTTP fetch is not dependable. Refresh the file with a browser, then re-run.
#
# Idempotent: games are keyed on (season, game_number), so re-running updates
# costs and dates in place instead of duplicating. Existing tickets are kept.
class ScheduleImporter
  OKC_ESPN_ID = "25".freeze
  CENTRAL = "America/Chicago".freeze

  # ESPN display names that differ from the Team records in this app.
  TEAM_NAME_ALIASES = {
    "LA Clippers" => "Los Angeles Clippers"
  }.freeze

  class Error < StandardError; end

  Result = Struct.new(:season, :created, :updated, :games, keyword_init: true)

  # season_year   - "2026-27"
  # total_cost    - full season invoice for all seats, parking included
  # parking_cost  - per-game parking, already part of total_cost
  # num_seats     - seats held per game
  # billed_games  - games the invoice covers, when that differs from the games
  #                 currently published (the NBA Cup window leaves late-season
  #                 home dates TBD). Defaults to the number of games imported.
  def initialize(season_year:, source_path:, total_cost:, parking_cost:, num_seats:, seat_section: nil, billed_games: nil, make_current: true)
    @season_year = season_year
    @source_path = source_path
    @total_cost = BigDecimal(total_cost.to_s)
    @parking_cost = BigDecimal(parking_cost.to_s)
    @num_seats = Integer(num_seats)
    @seat_section = seat_section
    @billed_games = billed_games&.to_i
    @make_current = make_current
  end

  def call
    games = home_games
    raise Error, "No home games found in #{@source_path}" if games.empty?

    cost_per_ticket = derive_cost_per_ticket(games.size)

    created = 0
    updated = 0
    season = nil

    ActiveRecord::Base.transaction do
      season = upsert_season
      games.each_with_index do |g, idx|
        record = Game.find_or_initialize_by(season: season, game_number: idx + 1)
        record.new_record? ? created += 1 : updated += 1
        record.assign_attributes(
          game_date: g[:date],
          opponent: find_team!(g[:opponent]),
          cost_per_ticket: cost_per_ticket,
          parking_cost: @parking_cost,
          game_type: "regular"
        )
        record.save!
      end
    end

    Result.new(season: season, created: created, updated: updated, games: games)
  end

  # Per-ticket cost implied by the season invoice, after backing out parking.
  # total = (cost_per_ticket * num_seats * games) + (parking * games)
  def derive_cost_per_ticket(game_count = nil)
    games = @billed_games || game_count or raise Error, "game count required"
    ticket_portion = @total_cost - (@parking_cost * games)
    if ticket_portion <= 0
      raise Error, "Parking (#{@parking_cost} x #{games}) meets or exceeds the season total #{@total_cost}"
    end

    (ticket_portion / (@num_seats * games)).round(2)
  end

  # Home games, chronological, as [{ date:, opponent:, tipoff:, nba_cup: }]
  def home_games
    payload = JSON.parse(File.read(@source_path))
    events = payload["events"] or raise Error, "#{@source_path} has no \"events\" key"

    events.filter_map { |event| parse_event(event) }
          .select { |g| g[:home] }
          .sort_by { |g| g[:tipoff] }
  end

  private

  def parse_event(event)
    competition = event.fetch("competitions").first
    okc, opponent = competition.fetch("competitors").partition { |c| c["id"] == OKC_ESPN_ID }
    return nil if okc.empty? || opponent.empty?

    tipoff = Time.parse(event.fetch("date")).in_time_zone(CENTRAL)
    notes = competition["notes"] || []

    {
      home: okc.first["homeAway"] == "home",
      tipoff: tipoff,
      date: tipoff.to_date,
      opponent: opponent.first.dig("team", "displayName"),
      nba_cup: notes.any? { |n| n["headline"].to_s.include?("Cup") }
    }
  end

  def upsert_season
    season = Season.find_or_initialize_by(year: @season_year)
    season.assign_attributes(
      num_seats: @num_seats,
      total_season_cost: @total_cost,
      is_current: @make_current
    )
    season.seat_section = @seat_section if @seat_section.present?
    season.save!

    Season.where.not(id: season.id).update_all(is_current: false) if @make_current
    season
  end

  def find_team!(espn_name)
    name = TEAM_NAME_ALIASES.fetch(espn_name, espn_name)
    Team.find_by(name: name) || raise(Error, "No Team record matches #{espn_name.inspect} (tried #{name.inspect})")
  end
end
