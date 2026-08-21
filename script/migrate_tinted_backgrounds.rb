# One-off: last few tinted backgrounds that the semantic pass didn't cover.
# Run from the app root: ruby script/migrate_tinted_backgrounds.rb

MAP = {
  "bg-green-900/50" => "bg-positive/15",
  "bg-red-900/50" => "bg-negative/15",
  "bg-yellow-900/20" => "bg-warning/10",
  "bg-yellow-900/50" => "bg-warning/15",
  "bg-orange-900/50" => "bg-warning/15",
  "bg-blue-900/20" => "bg-accent/10"
}.freeze

PATTERN = Regexp.union(MAP.keys.sort_by { |k| -k.length })

files = Dir.glob("app/views/**/*.erb").reject { |f| f.include?("mailer") }
changed = Hash.new(0)

files.each do |path|
  original = File.read(path)
  updated = original.gsub(PATTERN) do |match|
    changed[match] += 1
    MAP.fetch(match)
  end
  File.write(path, updated) unless updated == original
end

changed.sort_by { |_, v| -v }.each { |cls, n| puts format("%-22s %3d  ->  %s", cls, n, MAP[cls]) }
puts "\nTotal replacements: #{changed.values.sum}"
