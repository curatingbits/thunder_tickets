# One-off: migrate hardcoded gray utilities to semantic tokens.
# Run from the app root: ruby script/migrate_gray_to_tokens.rb
#
# Kept deliberately dumb — whole-word class replacement only, so it can't
# mangle ERB or partially rewrite a longer class name.

MAP = {
  # Surfaces (darkest -> lightest)
  "bg-gray-950" => "bg-canvas",
  "bg-gray-900" => "bg-canvas",
  "bg-gray-800" => "bg-surface",
  "bg-gray-750" => "bg-surface-raised", # not a real Tailwind color: rendered unstyled
  "bg-gray-700" => "bg-surface-raised",
  "bg-gray-600" => "bg-strong",

  # Borders
  "border-gray-800" => "border-subtle",
  "border-gray-700" => "border-subtle",
  "border-gray-600" => "border-strong",
  "divide-gray-700" => "divide-subtle",

  # Text, brightest -> dimmest
  "text-gray-100" => "text-content-strong",
  "text-gray-300" => "text-content",
  "text-gray-400" => "text-content-dim",
  "text-gray-500" => "text-muted",
  "text-gray-600" => "text-muted",

  # Hover states
  "hover:bg-gray-800" => "hover:bg-surface",
  "hover:bg-gray-700" => "hover:bg-surface-raised",
  "hover:bg-gray-600" => "hover:bg-strong",
  "hover:text-gray-300" => "hover:text-content",
  "placeholder-gray-500" => "placeholder-muted"
}.freeze

# Longest keys first so "hover:bg-gray-700" wins over "bg-gray-700".
PATTERN = Regexp.union(MAP.keys.sort_by { |k| -k.length })

files = Dir.glob("app/views/**/*.erb") + Dir.glob("app/helpers/**/*.rb")
changed = Hash.new(0)

files.each do |path|
  original = File.read(path)
  updated = original.gsub(PATTERN) do |match|
    changed[match] += 1
    MAP.fetch(match)
  end
  File.write(path, updated) unless updated == original
end

changed.sort_by { |_, v| -v }.each { |cls, n| puts format("%-24s %3d  ->  %s", cls, n, MAP[cls]) }
puts "\nTotal replacements: #{changed.values.sum} across #{files.size} files"
