# Per-request (and per-job) state, reset automatically between requests.
class Current < ActiveSupport::CurrentAttributes
  attribute :app_settings
end
