class DailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    # Send daily digest to all active users
    User.active.find_each do |user|
      UserMailer.with(user: user).daily_digest.deliver_later
    end
  end
end
