require "csv"

# Clear existing data
puts "Clearing existing data..."
Ticket.destroy_all
Game.destroy_all
Team.destroy_all
Season.destroy_all
User.destroy_all

# Create default admin user
puts "Creating default user..."
User.create!(
  email: "admin@thundertickets.com",
  password: "thunder2026",
  password_confirmation: "thunder2026",
  name: "Admin User",
  invited_by: "System"
)

# Create 2025-26 Season
puts "Creating 2025-26 season..."
season = Season.create!(
  year: "2025-26",
  is_current: true,
  num_seats: 3,
  total_season_cost: 17084.70
)

# Create NBA teams
puts "Creating NBA teams..."
teams = {
  "Houston Rockets" => "HOU",
  "Sacramento Kings" => "SAC",
  "Washington Wizards" => "WAS",
  "New Orleans Pelicans" => "NOP",
  "Golden State Warriors" => "GSW",
  "Los Angeles Lakers" => "LAL",
  "Portland Trail Blazers" => "POR",
  "Minnesota Timberwolves" => "MIN",
  "Phoenix Suns" => "PHX",
  "Dallas Mavericks" => "DAL",
  "Los Angeles Clippers" => "LAC",
  "Memphis Grizzlies" => "MEM",
  "San Antonio Spurs" => "SAS",
  "Philadelphia 76ers" => "PHI",
  "Atlanta Hawks" => "ATL",
  "Charlotte Hornets" => "CHA",
  "Utah Jazz" => "UTA",
  "Miami Heat" => "MIA",
  "Milwaukee Bucks" => "MIL",
  "Indiana Pacers" => "IND",
  "Toronto Raptors" => "TOR",
  "Orlando Magic" => "ORL",
  "Brooklyn Nets" => "BKN",
  "Cleveland Cavaliers" => "CLE",
  "Denver Nuggets" => "DEN",
  "Boston Celtics" => "BOS",
  "Chicago Bulls" => "CHI",
  "New York Knicks" => "NYK",
  "Detroit Pistons" => "DET"
}

teams.each do |name, abbr|
  Team.create!(name: name, abbreviation: abbr)
end

# Import games from CSV
puts "Importing games from CSV..."
csv_file = "/home/dkr/Downloads/2025-26 Thunder Tickets - Ticket Tracker.csv"

CSV.foreach(csv_file, headers: true) do |row|
  next if row["Game #"].nil? || row["Game #"].to_i == 0 # Skip summary row

  opponent_name = row["Opponent"]
  opponent = Team.find_by(name: opponent_name)

  unless opponent
    puts "Warning: Could not find team '#{opponent_name}'"
    next
  end

  # Parse cost values (remove $ and commas)
  cost_per_ticket = row["Cost per Ticket"].gsub(/[$,]/, "").to_f
  parking_cost = row["Parking Pass Cost"].gsub(/[$,]/, "").to_f

  # Parse date
  game_date = Date.parse(row["Date"])

  game = Game.create!(
    season: season,
    game_number: row["Game #"].to_i,
    game_date: game_date,
    opponent: opponent,
    cost_per_ticket: cost_per_ticket,
    parking_cost: parking_cost,
    game_type: "regular"
  )

  # Create tickets for sold seats
  [1, 2, 3].each do |seat_num|
    sold_price = row["Sold Ticket #{seat_num}"]
    next if sold_price.nil? || sold_price.strip.empty?

    sale_price = sold_price.gsub(/[$,]/, "").to_f
    next if sale_price.zero?

    Ticket.create!(
      game: game,
      seat_number: seat_num,
      sale_price: sale_price,
      buyer_name: "Initial Sale"
    )
  end
end

puts "\n=========================================="
puts "Seed completed successfully!"
puts "=========================================="
puts "Season: #{season.year}"
puts "Total Games: #{Game.count}"
puts "Total Teams: #{Team.count}"
puts "Total Tickets Sold: #{Ticket.count}"
puts "Total Season Cost: $#{season.total_cost}"
puts "Total Revenue: $#{season.total_revenue}"
puts "Current Profit/Loss: $#{season.total_profit}"
puts "=========================================="
puts "\nDefault Login:"
puts "Email: admin@thundertickets.com"
puts "Password: thunder2026"
puts "=========================================="
