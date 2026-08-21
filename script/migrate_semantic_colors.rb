# One-off: migrate semantic palette colors to semantic tokens.
# Run from the app root: ruby script/migrate_semantic_colors.rb
#
# Only maps colors that carry MEANING (profit/loss/warning/accent). Purely
# decorative colors (purple, sky, orange branding) are deliberately left alone.

MAP = {
  # Positive / money-good
  "text-green-400" => "text-positive",
  "text-green-500" => "text-positive",
  "text-green-200" => "text-positive",
  "text-emerald-400" => "text-positive",
  "bg-green-500" => "bg-positive",
  "border-green-700" => "border-positive/40",
  "bg-green-900/10" => "bg-positive/10",
  "bg-green-500/20" => "bg-positive/20",
  "hover:bg-green-700" => "hover:bg-positive",

  # Negative / money-bad
  "text-red-400" => "text-negative",
  "text-red-500" => "text-negative",
  "text-red-200" => "text-negative",
  "text-red-300" => "text-negative",
  "border-red-700" => "border-negative/40",
  "bg-red-900/10" => "bg-negative/10",
  "bg-red-500/20" => "bg-negative/20",
  "hover:text-red-300" => "hover:text-negative",

  # Warning / partial
  "text-yellow-400" => "text-warning",
  "text-amber-400" => "text-warning",
  "bg-yellow-500" => "bg-warning",
  "bg-yellow-500/20" => "bg-warning/20",
  "border-yellow-700" => "border-warning/40",
  "bg-amber-500/20" => "bg-warning/20",

  # Accent / interactive
  "text-blue-400" => "text-accent",
  "text-blue-300" => "text-accent",
  "hover:text-blue-300" => "hover:brightness-125",
  "group-hover:text-blue-400" => "group-hover:text-accent",
  "border-blue-400" => "border-accent",
  "hover:border-blue-500" => "hover:border-accent",
  "bg-blue-500/20" => "bg-accent/20",
  "focus:ring-blue-500" => "focus:ring-accent",

  # White text -> content-strong token
  "text-white" => "text-content-strong"
}.freeze

PATTERN = Regexp.union(MAP.keys.sort_by { |k| -k.length })

files = Dir.glob("app/views/**/*.erb").reject { |f| f.include?("mailer") || f.include?("layouts/mailer") }
changed = Hash.new(0)

files.each do |path|
  original = File.read(path)
  updated = original.gsub(PATTERN) do |match|
    changed[match] += 1
    MAP.fetch(match)
  end
  File.write(path, updated) unless updated == original
end

changed.sort_by { |_, v| -v }.each { |cls, n| puts format("%-26s %3d  ->  %s", cls, n, MAP[cls]) }
puts "\nTotal replacements: #{changed.values.sum} across #{files.size} files"
