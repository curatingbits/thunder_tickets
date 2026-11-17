module Settlements
  # Words Mark uses for each opponent: the team's nickname (and city, where
  # it's unambiguous) plus the shorthand seen in memos. Matched on whole
  # words, so "nets" never matches inside "hornets".
  module TeamAliases
    EXTRA = {
      "MIN" => %w[twolves t-wolves wolves], "CLE" => %w[cavs], "PHI" => %w[sixers 76ers], "DAL" => %w[mavs],
      "POR" => [ "blazers", "trail blazers" ], "NOP" => %w[pels], "MEM" => %w[grizz], "DEN" => %w[nugs],
      "GSW" => %w[dubs gsw], "LAC" => %w[clips], "BOS" => %w[celts], "TOR" => %w[raps], "WAS" => %w[wiz],
      "SAS" => [ "spurs" ], "NYK" => %w[knicks], "BKN" => %w[nets], "CHA" => %w[hornets], "LAL" => %w[lakers]
    }.freeze
    AMBIGUOUS_CITIES = [ "los angeles", "la", "new york" ].freeze

    module_function

    # { "hawks" => team_id, ... } for every Team, longest aliases first.
    def table
      teams = Team.all.to_a
      cities = teams.map { |t| city(t.name) }.tally
      aliases = teams.flat_map do |team|
        words = [ team.name.split.last.downcase, *EXTRA.fetch(team.abbreviation, []) ]
        c = city(team.name)
        words << c if cities[c] == 1 && !AMBIGUOUS_CITIES.include?(c)
        words << "trail blazers" if team.abbreviation == "POR"
        words.uniq.map { |w| [ w, team.id ] }
      end
      aliases.sort_by { |w, _| -w.length }.to_h
    end

    def city(name)
      name.split[0..-2].join(" ").downcase
    end

    # Team ids named in a piece of memo text, in the order they appear.
    def find(text, table = self.table)
      found = []
      remaining = text.dup
      table.each do |word, team_id|
        pattern = /(?<![\w-])#{Regexp.escape(word)}(?![\w-])/
        while (m = remaining.match(pattern))
          found << [ m.begin(0), team_id ]
          remaining[m.begin(0)...m.end(0)] = " " * word.length
        end
      end
      found.sort_by(&:first).map(&:last).uniq
    end
  end
end
