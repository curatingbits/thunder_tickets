# Configure Resend API for email delivery
# https://resend.com/docs/send-with-rails

Resend.configure do |config|
  config.api_key = ENV["RESEND_API_KEY"]
end
