# Imports OKC home games for a season from cached ESPN team-schedule JSON files.
#
# The JSON is the payload of:
#   https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams/okc/schedule?season=<end_year>&seasontype=<1|2>
#
#   seasontype=1 -> preseason, seasontype=2 -> regular season
#
# Files are cached under db/schedules/ rather than fetched at runtime: ESPN's
# edge (Akamai) rejects non-browser clients with 403, so an unattended HTTP
# fetch is not dependable. Refresh them with a browser, then re-run.
#
# Idempotent: games are keyed on (season, game_number), so re-running updates
# costs and dates in place instead of duplicating. Existing tickets are kept.
class ScheduleImporter
  OKC_ESPN_ID = "25".freeze
  CENTRAL = "America/Chicago".freeze

  # The seats this app tracks are at Paycom Center. OKC plays an annual
  # preseason exhibition in Tulsa (BOK Center) that season-ticket holders do
  # not receive, so home games are filtered by venue.
  HOME_VENUE = "Paycom Center".freeze

  # ESPN seasonType abbreviations -> this app's game_type values.
  GAME_TYPE_BY_SEASON_TYPE = {
    "pre" => "preseason",
    "reg" => "regular"
  }.freeze

  # ESPN display names that differ from the Team records in this app.
  TEAM_NAME_ALIASES = {
    "LA Clippers" => "Los Angeles Clippers"
  }.freeze

  class Error < StandardError; end

  Result = Struct.new(:season, :created, :updated, :games, :cost_per_ticket, keyword_init: true)

  # season_year   - "2026-27"
  # source_paths  - one or more cached ESPN payloads (preseason and/or regular)
  # total_cost    - full season invoice for all seats, parking included
  # parking_cost  - per-game parking, already part of total_cost
  # num_seats     - seats held per game
  # billed_games  - games the invoice covers, when that differs from the games
  #                 currently published (the NBA Cup window leaves two late
  #                 season dates TBD). Defaults to the number of games imported.
  def initialize(season_year:, source_paths:, total_cost:, parking_cost:, num_seats:,
                 seat_section: nil, billed_games: nil, make_current: true)
    @season_year = season_year
    @source_paths = Array(source_paths)
    @total_cost = BigDecimal(total_cost.to_s)
    @parking_cost = BigDecimal(parking_cost.to_s)
    @num_seats = Integer(num_seats)
    @seat_section = seat_section
    @billed_games = billed_games&.to_i
    @make_current = make_current
  end

  def call
    games = home_games
    raise Error, "No home games found in #{@source_paths.join(', ')}" if games.empty?

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
          game_type: g[:game_type],
          playoff_round: g[:nba_cup] ? "Group Play" : nil
        )
        record.save!
      end
    end

    Result.new(season: season, created: created, updated: updated, games: games,
               cost_per_ticket: cost_per_ticket)
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

  # What the derived per-ticket cost actually re-totals to, so a caller can
  # report the rounding drift against the invoice.
  def reconciled_total(game_count)
    games = @billed_games || game_count
    (derive_cost_per_ticket(game_count) * @num_seats * games) + (@parking_cost * games)
  end

  # Home games at HOME_VENUE across every source file, chronological.
  # Preseason sorts before the regular season because it happens first.
  def home_games
    @source_paths.flat_map { |path| parse_file(path) }
                 .select { |g| g[:home] && g[:venue] == HOME_VENUE }
                 .sort_by { |g| g[:tipoff] }
  end

  # Home games that were dropped for being at another venue (the Tulsa
  # exhibition), so the caller can say so out loud rather than silently
  # under-importing.
  def excluded_home_games
    @source_paths.flat_map { |path| parse_file(path) }
                 .select { |g| g[:home] && g[:venue] != HOME_VENUE }
                 .sort_by { |g| g[:tipoff] }
  end

  private

  def parse_file(path)
    raise Error, "Schedule file not found: #{path}" unless File.exist?(path)

    payload = JSON.parse(File.read(path))
    events = payload["events"] or raise Error, "#{path} has no \"events\" key"
    events.filter_map { |event| parse_event(event, path) }
  end

  def parse_event(event, path)
    competition = event.fetch("competitions").first
    okc, opponent = competition.fetch("competitors").partition { |c| c["id"] == OKC_ESPN_ID }
    return nil if okc.empty? || opponent.empty?

    # Per-event seasonType is authoritative; the payload's top-level season
    # block reports type 1 on both the preseason and regular-season feeds.
    abbreviation = event.dig("seasonType", "abbreviation")
    game_type = GAME_TYPE_BY_SEASON_TYPE[abbreviation]
    raise Error, "Unsupported seasonType #{abbreviation.inspect} in #{path}" if game_type.nil?

    tipoff = Time.parse(event.fetch("date")).in_time_zone(CENTRAL)
    notes = competition["notes"] || []

    {
      home: okc.first["homeAway"] == "home",
      venue: competition.dig("venue", "fullName"),
      tipoff: tipoff,
      date: tipoff.to_date,
      opponent: opponent.first.dig("team", "displayName"),
      game_type: game_type,
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
