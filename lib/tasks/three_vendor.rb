require "digest"
require "json"
require "net/http"

# three.js for the 3D seat map on Pricing, vendored by hand the way Invintory's 3D fridges do it. importmap's own pin and
# update fetch a different build under other file names, so never run them on these: three:vendor is the only way in.
#
# It downloads the exact version's files from jsDelivr. They are npm's published files, and a published version never
# changes, so every file's sha256 goes in vendor/three-manifest.json and a later download must match it byte for byte.
# Each import is then pointed at the name config/importmap.rb pins, and three:verify checks the files on disk against
# the manifest (bin/ci runs it).
module ThreeVendor
  VERSION = "0.187.0"
  SOURCE = "https://cdn.jsdelivr.net/npm/three@#{VERSION}/"

  # Where each file goes under vendor/javascript => where it is in the package.
  FILES = {
    "three.module.js" => "build/three.module.js",
    "three.core.js" => "build/three.core.js",
    "three/addons/controls/OrbitControls.js" => "examples/jsm/controls/OrbitControls.js",
    "three/addons/geometries/RoundedBoxGeometry.js" => "examples/jsm/geometries/RoundedBoxGeometry.js"
  }.freeze

  # three.module.js imports the core by a relative path, which can't reach Propshaft's digested file name, so it imports
  # the core's pin instead. The addons already import "three", the renderer's pin.
  REWRITES = { "three.module.js" => { "from './three.core.js'" => "from 'three/core'" } }.freeze

  DIR = Rails.root.join("vendor/javascript")
  MANIFEST = Rails.root.join("vendor/three-manifest.json")

  module_function

  def vendor!
    known = manifest_for_this_version
    files = FILES.to_h do |path, upstream|
      body = download("#{SOURCE}#{upstream}")
      upstream_sha = Digest::SHA256.hexdigest(body)
      if (recorded = known.dig(path, "upstream_sha256")) && recorded != upstream_sha
        abort "three:vendor: jsDelivr served #{upstream} with sha256 #{upstream_sha}, but #{VERSION} was vendored " \
              "with #{recorded}. A published npm version never changes, so nothing was written."
      end
      vendored = rewrite(path, body)
      DIR.join(path).dirname.mkpath
      DIR.join(path).binwrite(vendored)
      puts "  #{path} (#{vendored.bytesize} bytes)"
      [ path, { "from" => upstream, "upstream_sha256" => upstream_sha, "sha256" => Digest::SHA256.hexdigest(vendored) } ]
    end
    MANIFEST.write(JSON.pretty_generate("version" => VERSION, "source" => SOURCE, "files" => files) + "\n")
    puts "three.js #{VERSION} vendored; sha256s in #{MANIFEST.relative_path_from(Rails.root)}."
  end

  def verify!
    abort "three:verify: #{MANIFEST.relative_path_from(Rails.root)} is missing; run bin/rails three:vendor." unless MANIFEST.exist?
    manifest = JSON.parse(MANIFEST.read)
    abort "three:verify: the manifest is for #{manifest["version"]}, the task for #{VERSION}." if manifest["version"] != VERSION
    abort "three:verify: the manifest lists other files than the task vendors." if manifest["files"].keys.sort != FILES.keys.sort

    manifest["files"].each do |path, entry|
      file = DIR.join(path)
      abort "three:verify: vendor/javascript/#{path} is missing." unless file.exist?
      actual = Digest::SHA256.file(file).hexdigest
      abort "three:verify: vendor/javascript/#{path} has sha256 #{actual}, the manifest #{entry["sha256"]}." if actual != entry["sha256"]
    end
    puts "three.js #{VERSION}: #{FILES.size} files match the manifest."
  end

  def manifest_for_this_version
    return {} unless MANIFEST.exist?
    manifest = JSON.parse(MANIFEST.read)
    manifest["version"] == VERSION ? manifest["files"] : {}
  end

  def download(url)
    response = Net::HTTP.get_response(URI(url))
    abort "three:vendor: #{url} answered #{response.code}." unless response.is_a?(Net::HTTPOK)
    response.body.b
  end

  # Each rewrite must find what it replaces: if it doesn't, the file has changed shape and its imports need a look.
  def rewrite(path, body)
    REWRITES.fetch(path, {}).reduce(body.dup.force_encoding(Encoding::UTF_8)) do |text, (from, to)|
      abort "three:vendor: #{path} no longer contains #{from}." unless text.include?(from)
      text.gsub(from, to)
    end.b
  end
end
