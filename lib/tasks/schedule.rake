require Rails.root.join("lib/schedule_importer")

namespace :schedule do
  desc "Import OKC home games. Usage: rake schedule:import YEAR=2026-27 TOTAL=20842.80 PARKING=8.70 SEATS=3 SECTION=101 [PRESEASON=1] [BILLED_GAMES=41] [DRY_RUN=1]"
  task import: :environment do
    year = ENV.fetch("YEAR")
    total = ENV.fetch("TOTAL")
    parking = ENV.fetch("PARKING")
    seats = ENV.fetch("SEATS", "3")
    section = ENV["SECTION"]
    dry_run = ENV["DRY_RUN"].present?

    sources = ENV["SOURCES"].presence&.split(",")&.map(&:strip) || default_sources(year)
    missing = sources.reject { |p| File.exist?(p) }
    abort "Schedule file(s) not found: #{missing.join(', ')}" if missing.any?

    importer = ScheduleImporter.new(
      season_year: year,
      source_paths: sources,
      total_cost: total,
      parking_cost: parking,
      num_seats: seats,
      seat_section: section,
      billed_games: ENV["BILLED_GAMES"]
    )

    games = importer.home_games
    cost_per_ticket = importer.derive_cost_per_ticket(games.size)
    excluded = importer.excluded_home_games

    puts "Sources: #{sources.map { |s| File.basename(s) }.join(', ')}"
    puts "#{games.size} home games at #{ScheduleImporter::HOME_VENUE}"
    games.group_by { |g| g[:game_type] }.each do |type, list|
      puts "  #{list.size} #{type}"
    end

    if excluded.any?
      puts "\nExcluded #{excluded.size} home game(s) at another venue:"
      excluded.each { |g| puts "  #{g[:date]}  #{g[:opponent]}  (#{g[:venue]})" }
    end

    puts "\nCost per ticket: $#{cost_per_ticket}  (#{seats} seats, parking $#{parking}/game)"
    reconciled = importer.reconciled_total(games.size)
    delta = reconciled - BigDecimal(total.to_s)
    puts "Reconciles to: $#{reconciled}  (invoice $#{total}, delta #{delta.negative? ? '' : '+'}$#{delta.round(2)})"

    if dry_run
      puts "\nDRY RUN — nothing written."
      games.each_with_index do |g, i|
        tag = g[:game_type] == "preseason" ? "PRE" : (g[:nba_cup] ? "CUP" : "")
        puts format("%2d  %s  %-24s %s", i + 1, g[:date], g[:opponent], tag)
      end
      next
    end

    result = importer.call
    puts "\nSeason #{result.season.year}: #{result.created} games created, #{result.updated} updated"
    puts "Computed season cost: $#{result.season.total_cost}  (invoice: $#{result.season.total_season_cost})"
  end

  # Preseason is opt-in: a plan that only covers the regular season shouldn't
  # silently pick up exhibition games.
  def default_sources(year)
    regular = Rails.root.join("db/schedules/#{year}.json").to_s
    return [regular] unless ENV["PRESEASON"].present?

    [Rails.root.join("db/schedules/#{year}-preseason.json").to_s, regular]
  end
end
