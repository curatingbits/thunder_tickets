require "test_helper"

class Market::SeatMapTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 11, 16, 12)
    @game = seasons(:current).games.create!(game_number: 101, game_date: Date.new(2026, 11, 18), opponent: teams(:rockets),
                                            cost_per_ticket: 162.52, parking_cost: 8.70, game_type: "regular")
    payload = Market::ScrapeFile.payloads(JSON.parse(file_fixture("tm_scrape_sample.json").read), captured_at: Time.current)
                                .find { |p| p[:event_date] == "2026-11-18" }
    near = payload[:listings].find { |l| l[:section] == "101" && %w[AA BB CC EE FF GG].include?(l[:row]) }
    near[:seats] = [ 4, 5 ]
    payload[:listings] << { position: 99, section: "119", row: "EE", price: 171.0, ticket_type: "verified_resale",
                            raw_label: "Sec 119 • Row EE $171.00" }
    # A pasted scan can hold any section; one the map doesn't draw.
    payload[:listings] << { position: 98, section: "103", row: "AA", price: 140.0, ticket_type: "verified_resale",
                            raw_label: "Sec 103 • Row AA $140.00" }
    run = ImportRun.create!(kind: "market_research", source: "backfill", key: "t", status: "completed", started_at: Time.current)
    @snapshot = Market::ScanIngest.new(run: run, game: @game, payload: payload).call.snapshot
    @settings = Market::Settings.for(seasons(:current))
    @map = Market::SeatMap.new(@snapshot, settings: @settings, our_all_in: 309.83)
    @near_position = near[:position]
  end

  test "every listing read, in a role that says what it did to the market value" do
    roles = @map.entries.group_by(&:role)

    assert_equal @snapshot.observations.count, @map.entries.size
    assert_equal @snapshot.tier2_count + @snapshot.tier3_count, roles["comparable"].size
    assert_in_delta 100, roles["comparable"].sum(&:share), 0.5, "comparable shares are the whole weight"
    assert roles["baseline"].all? { |e| e.section == "101" }
    assert_equal "context section, never priced", roles["context"].find { |e| e.section == "119" }.note
    assert_equal Market::SeatMap::ROLES.keys & roles.keys, roles.keys, "listed in role order"
  end

  test "a listing keeps the seats the research read; others are row only" do
    near = @map.entries.find { |e| e.id == @snapshot.observations.find_by!(position: @near_position).id }

    assert_equal [ 4, 5 ], near.seats
    assert @map.entries.reject { |e| e.id == near.id }.all? { |e| e.seats.nil? }
  end

  test "the client data: listings on the map, our seats and the price span" do
    data = @map.to_client

    assert_equal({ section: "101", row: "DD", seats: [ 1, 2, 3 ], all_in: 309.83 }, data[:ours])
    low, high = data[:range]
    assert_operator low, :<, high
    assert data[:listings].all? { |l| Venue::Layout.paycom.row(l[:section], l[:row]) }
    assert_equal @map.entries.count(&:on_map), data[:listings].size
  end

  test "a listing outside the mapped sections is listed but not drawn" do
    elsewhere = @map.entries.find { |e| e.section == "103" }

    assert_not elsewhere.on_map
    assert_equal "section 103 isn't compared · not on the map", elsewhere.note
    assert_not @map.to_client[:listings].any? { |l| l[:section] == "103" }
  end
end
