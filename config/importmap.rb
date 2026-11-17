# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Chart.js for dashboard visualizations (auto-register version)
pin "chart.js/auto", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/auto/+esm"

# The 3D seat map on Pricing. Only seat_map_controller.js loads these, by a
# dynamic import of arena3d/viewer when the map is switched on, so none of
# them preload on any page. three.js 0.187.0 is vendored by hand with
# bin/rails three:vendor (lib/tasks/three.rake), which checks every file
# against vendor/three-manifest.json. Never bin/importmap pin or update it:
# that fetches another build under other names. The jsdelivr comment is how
# bin/importmap audit reads the version.
pin "three", to: "three.module.js", preload: false # cdn.jsdelivr.net/npm/three@0.187.0/build/three.module.js
pin "three/core", to: "three.core.js", preload: false
pin "three/addons/controls/OrbitControls", to: "three/addons/controls/OrbitControls.js", preload: false
pin "three/addons/geometries/RoundedBoxGeometry", to: "three/addons/geometries/RoundedBoxGeometry.js", preload: false
pin_all_from "app/javascript/arena3d", under: "arena3d", preload: false
