module Settlements
  # Reads a Venmo payment's name field ("Mark Augspurger \"Thunder vs hawks
  # 11/18 AND Thunder vs nets 12/2 ⚡⚡⚡\"") into the payer, the memo, and one
  # reference per game it mentions: opponent, M/D date, preseason/playoff
  # hints, "half of 3rd ticket", and a buyer ("to Kolton").
  module MemoParser
    Reference = Data.define(:team_ids, :date, :preseason, :playoff, :game_number, :partial, :buyer)
    Parsed = Data.define(:payer, :memo, :references, :thunder) do
      def any_reference? = references.any? { |r| r.team_ids.any? || r.date }
    end

    EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]/
    NAME_AND_MEMO = /\A(?<payer>[^"“]+?)\s*["“](?<memo>.*)["”]\s*\z/m
    SPLIT = /\s+(?:and|&|\+)\s+/i
    DATE = %r{(?<![\d/])(\d{1,2})/(\d{1,2})(?![\d/])}

    module_function

    def parse(name, season: nil, aliases: TeamAliases.table)
      m = name.to_s.match(NAME_AND_MEMO)
      payer = m ? m[:payer].strip : nil
      memo = m ? m[:memo] : name.to_s
      thunder = memo.include?("⚡") || memo.match?(/thunder/i)
      clean = memo.gsub(EMOJI, " ").downcase.squish
      references = clean.split(SPLIT).map { |segment| reference(segment, season, aliases) }
      Parsed.new(payer: payer, memo: memo.strip, references: references, thunder: thunder)
    end

    def reference(segment, season, aliases)
      Reference.new(
        team_ids: TeamAliases.find(segment, aliases),
        date: date_in(segment, season),
        preseason: segment.match?(/\bpre-?season\b/),
        playoff: segment.match?(/\b(?:playoffs?|wcf|ecf|finals|round \d)\b/),
        game_number: segment[/\bgame\s*(\d)\b/, 1]&.to_i,
        partial: segment.match?(/\b(?:\d(?:st|nd|rd|th)|one|1)\s+(?:ticket|tix)\b|\bhalf of\b/),
        buyer: segment[/\bto\s+([a-z][a-z'-]+)\b/, 1]&.capitalize
      )
    end

    # "11/18" in the season's date range (any year it falls in).
    def date_in(segment, season)
      month, day = segment.match(DATE)&.captures&.map(&:to_i)
      return unless month && day && (1..12).cover?(month) && (1..31).cover?(day)

      years = season ? (season.games.minimum(:game_date)&.year..season.games.maximum(:game_date)&.year).to_a.compact : []
      years = [ Date.current.year - 1, Date.current.year, Date.current.year + 1 ] if years.empty?
      candidates = years.filter_map { |y| Date.new(y, month, day) rescue nil }
      return candidates.first unless season

      first = season.games.minimum(:game_date)
      last = season.games.maximum(:game_date)
      candidates.find { |d| d.between?(first - 30, last + 30) } || candidates.first
    end
  end
end
