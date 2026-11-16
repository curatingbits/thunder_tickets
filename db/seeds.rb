# Seeds only add what's missing. They never change or delete existing records,
# so running them against a database with real data is safe.
#
#   Every environment: the 29 teams the Thunder can host.
#   Development and test: a sign-in plus a sample 2026-27 season (the real
#   home schedule from db/schedules with made-up sales), and only when the
#   database has no seasons yet.
#
# Real seasons are loaded with `bin/rails schedule:import` (lib/tasks/schedule.rake).

# Names match ESPN's display names so ScheduleImporter can find them.
teams = {
  "Atlanta Hawks" => "ATL",
  "Boston Celtics" => "BOS",
  "Brooklyn Nets" => "BKN",
  "Charlotte Hornets" => "CHA",
  "Chicago Bulls" => "CHI",
  "Cleveland Cavaliers" => "CLE",
  "Dallas Mavericks" => "DAL",
  "Denver Nuggets" => "DEN",
  "Detroit Pistons" => "DET",
  "Golden State Warriors" => "GSW",
  "Houston Rockets" => "HOU",
  "Indiana Pacers" => "IND",
  "Los Angeles Clippers" => "LAC",
  "Los Angeles Lakers" => "LAL",
  "Memphis Grizzlies" => "MEM",
  "Miami Heat" => "MIA",
  "Milwaukee Bucks" => "MIL",
  "Minnesota Timberwolves" => "MIN",
  "New Orleans Pelicans" => "NOP",
  "New York Knicks" => "NYK",
  "Orlando Magic" => "ORL",
  "Philadelphia 76ers" => "PHI",
  "Phoenix Suns" => "PHX",
  "Portland Trail Blazers" => "POR",
  "Sacramento Kings" => "SAC",
  "San Antonio Spurs" => "SAS",
  "Toronto Raptors" => "TOR",
  "Utah Jazz" => "UTA",
  "Washington Wizards" => "WAS"
}

teams.each do |name, abbreviation|
  Team.find_or_create_by!(name: name) { |team| team.abbreviation = abbreviation }
end
puts "Teams: #{Team.count}"

if Rails.env.production?
  puts "Production gets teams only. Load a season with `bin/rails schedule:import`."
  return
end

if Season.exists?
  puts "Seasons already exist, so no sample data was added."
  return
end

User.find_or_create_by!(email: "admin@example.com") do |user|
  user.name = "Sample Admin"
  user.password = user.password_confirmation = "password"
  user.invited_by = "Seeds"
end

# The same numbers `schedule:import` is documented with.
schedules = Rails.root.join("db/schedules")
season = ScheduleImporter.new(
  season_year: "2026-27",
  source_paths: [ schedules.join("2026-27-preseason.json").to_s, schedules.join("2026-27.json").to_s ],
  total_cost: "20842.80",
  parking_cost: "8.70",
  num_seats: 3,
  seat_section: "101"
).call.season

buyers = [
  [ "Jordan Avery", "jordan@example.com" ],
  [ "Sam Patel", "sam@example.com" ],
  [ "Riley Chen", "riley@example.com" ],
  [ "Morgan Diaz", nil ]
].map { |name, email| Buyer.create!(name: name, email: email) }

# Sale price as a multiple of cost, cycled so some sales win and some lose.
markups = [ 1.6, 0.85, 1.25, 2.4, 0.7, 1.1, 1.45 ]

season.games.order(:game_date).each_with_index do |game, i|
  seats_sold =
    if game.game_date < Date.current
      [ 3, 2, 3, 3, 1, 3, 2 ][i % 7]
    elsif game.game_date <= 3.weeks.from_now.to_date
      [ 1, 0, 2 ][i % 3]
    else
      0
    end

  1.upto(seats_sold) do |seat|
    n = i + seat
    sold_at = (game.game_date - (3 + n % 10).days).in_time_zone.change(hour: 12)
    game.tickets.create!(
      seat_number: seat,
      section: "101",
      row: "DD",
      sale_price: (game.cost_per_ticket * markups[n % markups.size]).round,
      buyer: buyers[n % (buyers.size + 1)], # every fifth sale has no buyer
      sold_at: [ sold_at, Time.current ].min
    )
  end
end

puts "Season #{season.year}: #{season.games.count} games, #{Ticket.count} sales, #{Buyer.count} buyers"
puts "Sign in as admin@example.com / password"
