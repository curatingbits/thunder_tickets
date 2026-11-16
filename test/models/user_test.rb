require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
  end

  # --- password reset --------------------------------------------------

  test "reset_password sets the new password and burns the token" do
    @user.generate_reset_token!

    assert @user.reset_password("newpass123", "newpass123")
    @user.reload
    assert @user.authenticate("newpass123")
    assert_nil @user.reset_password_token
    assert_nil @user.reset_password_sent_at
  end

  test "reset_password requires a password even without an accepted invitation" do
    # The admin fixture never went through an invitation, which is exactly the
    # case where the general password validation is skipped.
    assert_nil @user.invitation_accepted_at
    refute @user.reset_password("", "")
    assert @user.errors[:password].any?
  end

  test "reset_password requires a matching confirmation" do
    refute @user.reset_password("newpass123", "different")
    assert @user.errors[:password_confirmation].any?
  end

  test "find_by_reset_token ignores blank and expired tokens" do
    @user.generate_reset_token!
    token = @user.reset_password_token

    assert_equal @user, User.find_by_reset_token(token)
    assert_nil User.find_by_reset_token(nil)
    assert_nil User.find_by_reset_token("")

    travel User::RESET_TOKEN_TTL + 1.minute do
      assert_nil User.find_by_reset_token(token)
    end
  end

  # --- invitations -----------------------------------------------------

  test "accepting an invitation requires a matching confirmation" do
    invitee = User.new(name: "New Person", email: "new@example.com", active: false)
    invitee.save!(validate: false)
    invitee.generate_invitation_token!

    refute invitee.accept_invitation!("newpass123", "different")
    assert invitee.reload.invitation_pending?
  end
end
