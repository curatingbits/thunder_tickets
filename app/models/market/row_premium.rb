module Market
  # How much more rows near DD go for than the section's median. Learned from
  # this season's snapshots once 8+ games have both numbers; until then the
  # configured default (1.45, from Kate's data: 1.46).
  module RowPremium
    MIN_GAMES = 8
    WINDOW = 60.days

    def self.for(season, settings, now: Time.current)
      latest = MarketSnapshot.valid.joins(:game).where(games: { season_id: season.id })
                             .where(captured_at: (now - WINDOW)..now)
                             .where.not(near_raw_median: nil).where.not(section_median: nil)
                             .order(captured_at: :desc).to_a.uniq(&:game_id)
      ratios = latest.map { |s| (s.near_raw_median / s.section_median).to_f }
      if ratios.size >= MIN_GAMES
        [ Stats.median(ratios).round(3), "learned from #{ratios.size} games" ]
      else
        [ settings.row_premium_default, "default" ]
      end
    end
  end
end
