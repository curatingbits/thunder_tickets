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
end
