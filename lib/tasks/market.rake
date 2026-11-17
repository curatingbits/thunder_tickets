namespace :market do
  desc "Import a Ticketmaster scrape file (Kate's format) as one research run. " \
       "Usage: rake market:import_scrape FILE=tm_101_prices.json KEY=backfill-kate-2026-11-16 CAPTURED_AT=2026-11-16T10:02:39-06:00"
  task import_scrape: :environment do
    file = ENV.fetch("FILE")
    key = ENV.fetch("KEY")
    captured_at = Time.zone.parse(ENV.fetch("CAPTURED_AT"))
    season = Season.find_by!(is_current: true)

    run, = ImportRun.start!(kind: "market_research", source: "backfill", key: key, client_id: "rake-#{Process.pid}",
                            params: { "file" => File.basename(file) }, agent_version: "scrape-file")
    payloads = Market::ScrapeFile.payloads(JSON.parse(File.read(file)), captured_at: captured_at)
    payloads.sort_by { |p| p[:event_date].to_s }.each do |payload|
      game = season.games.find_by(game_date: payload[:event_date])
      unless game
        puts "  skip #{payload[:event_date]}: no game that day"
        next
      end
      result = Market::ScanIngest.new(run: run, game: game, payload: payload).call
      s = result.snapshot
      puts format("  %s %-4s market %8s  rec %-11s list $%-5s conf %3d  comps %d/%d/%d%s",
                  game.game_date, game.opponent.abbreviation, s.market_value ? "$#{s.market_value.round}" : "—",
                  s.recommended_strategy || "—", s.recommended_list_price || "—", s.confidence_now,
                  s.tier1_count, s.tier2_count, s.tier3_count, result.replayed ? "  (already imported)" : "")
    end
    run.finish!("completed", targeted: payloads.size)
    puts "Run #{run.key}: #{run.status}, #{run.market_snapshots.count} snapshots"
  end
end
