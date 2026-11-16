require "application_system_test_case"

# Phone-sized system tests: a 390x844 viewport (iPhone 14/15) with touch.
# Device metrics only. Chrome's iPhone presets also send an old iOS Safari
# user agent, which allow_browser :modern answers with a 406.
class MobileSystemTestCase < ApplicationSystemTestCase
  # The name keeps Capybara from replacing the desktop :selenium driver,
  # which every system test would then share.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ], options: { name: :mobile_chrome } do |options|
    options.add_emulation(device_metrics: { width: 390, height: 844, pixelRatio: 3, touch: true })
  end
end
