require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "password_reset links to the reset page with the token" do
    user = users(:admin)
    email = UserMailer.with(user: user, token: "abc123").password_reset

    assert_equal [ user.email ], email.to
    assert_equal [ "noreply@madrtickets.com" ], email.from
    assert_equal "Reset your MADR TICKETS password", email.subject

    reset_url = "http://example.com/password_resets/abc123/edit"
    assert_includes email.html_part.body.to_s, reset_url
    assert_includes email.text_part.body.to_s, reset_url
    assert_includes email.text_part.body.to_s, "expires in 2 hours"
  end

  test "the daily digest leads with what needs attention" do
    travel_to Time.zone.local(2026, 11, 18, 6)
    game = seasons(:current).games.create!(game_number: 800, game_date: Date.new(2026, 11, 20), opponent: teams(:rockets),
                                           cost_per_ticket: 100, parking_cost: 10, game_type: "regular")
    email = UserMailer.with(user: users(:admin)).daily_digest

    text = email.text_part.body.to_s
    assert_includes text, "NEEDS ATTENTION"
    assert_includes text, "3 seats to sell vs Houston Rockets"
    assert_includes text, "http://example.com/games/#{game.id}"
    assert_includes email.html_part.body.to_s, "3 seats to sell vs Houston Rockets"
  end
end
