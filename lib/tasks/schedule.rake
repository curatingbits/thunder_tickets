require Rails.root.join("lib/schedule_importer")

namespace :schedule do
  desc "Import OKC home games for a season. Usage: rake schedule:import YEAR=2026-27 TOTAL=20842.80 PARKING=8.70 SEATS=3 SECTION=101 [BILLED_GAMES=41] [DRY_RUN=1]"
  task import: :environment do
    year = ENV.fetch("YEAR")
    total = ENV.fetch("TOTAL")
    parking = ENV.fetch("PARKING")
    seats = ENV.fetch("SEATS", "3")
    section = ENV["SECTION"]
    source = ENV.fetch("SOURCE", Rails.root.join("db/schedules/#{year}.json").to_s)
    dry_run = ENV["DRY_RUN"].present?

    importer = ScheduleImporter.new(
      season_year: year,
      source_path: source,
      total_cost: total,
      parking_cost: parking,
      num_seats: seats,
      seat_section: section,
      billed_games: ENV["BILLED_GAMES"]
    )

    if dry_run
      games = importer.home_games
      cpt = importer.derive_cost_per_ticket(games.size)
      puts "DRY RUN — #{games.size} home games from #{source}"
      puts "Cost per ticket: $#{cpt}  (#{seats} seats, parking $#{parking}/game)"
      games.each_with_index do |g, i|
        puts format("%2d  %s  %-24s %s", i + 1, g[:date], g[:opponent], g[:nba_cup] ? "NBA Cup" : "")
      end
      next
    end

    result = importer.call
    season = result.season

    puts "Season #{season.year}: #{result.created} games created, #{result.updated} updated"
    puts "Cost per ticket: $#{season.games.first.cost_per_ticket}  Parking: $#{season.games.first.parking_cost}/game"
    puts "Computed season cost: $#{season.total_cost}  (invoice: $#{season.total_season_cost})"
    delta = season.total_cost - season.total_season_cost
    puts "Rounding delta: $#{delta.round(2)}" unless delta.zero?
  end
end
