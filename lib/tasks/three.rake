# bin/rails three:vendor and three:verify (ThreeVendor, in three_vendor.rb beside this: a plain file, so loading the
# tasks twice doesn't define it twice).
require_relative "three_vendor"

namespace :three do
  desc "Download three.js #{ThreeVendor::VERSION} from jsDelivr into vendor/javascript, recording or checking each file's sha256"
  task :vendor do
    ThreeVendor.vendor!
    ThreeVendor.verify!
  end

  desc "Check the vendored three.js files against vendor/three-manifest.json"
  task :verify do
    ThreeVendor.verify!
  end
end
