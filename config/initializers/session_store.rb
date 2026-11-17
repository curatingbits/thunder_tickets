# A login lasts a year from sign-in (User's :login token). The session cookie
# is persistent and renewed on each visit, so closing the browser or the
# home-screen app doesn't sign anyone out. Same cookie name as Rails' default.
Rails.application.configure do
  config.x.login_lasts = 1.year
  config.session_store :cookie_store, key: "_thunder_tickets_session", expire_after: config.x.login_lasts
end
