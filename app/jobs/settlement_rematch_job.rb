# Re-runs the payment matcher, one at a time. Enqueued after payment imports
# and whenever a sale changes, so a payment that arrived before its sale was
# entered settles once it is.
class SettlementRematchJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: "settlements", duration: 5.minutes

  def perform
    Settlements::Matcher.new.run
  end
end
