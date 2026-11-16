require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
  end

  test "should get new" do
    get new_password_reset_path
    assert_response :success
  end

  # --- create ----------------------------------------------------------

  test "create emails a reset link to an active user" do
    assert_enqueued_emails 1 do
      post password_resets_path, params: { email: @user.email }
    end
    assert_redirected_to login_path
    assert @user.reload.reset_password_token.present?
  end

  test "create matches the email regardless of case and whitespace" do
    assert_enqueued_emails 1 do
      post password_resets_path, params: { email: "  #{@user.email.upcase} " }
    end
  end

  test "create sends nothing for an unknown email but responds identically" do
    assert_no_enqueued_emails do
      post password_resets_path, params: { email: "nobody@example.com" }
    end
    assert_redirected_to login_path
    unknown_notice = flash[:notice]

    post password_resets_path, params: { email: @user.email }
    assert_equal unknown_notice, flash[:notice], "responses must not reveal which emails exist"
  end

  test "create sends nothing to a deactivated user" do
    @user.update!(active: false)

    assert_no_enqueued_emails do
      post password_resets_path, params: { email: @user.email }
    end
    assert_redirected_to login_path
  end

  # --- end to end ------------------------------------------------------

  test "the emailed link resets the password" do
    perform_enqueued_jobs do
      post password_resets_path, params: { email: @user.email }
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email ], email.to
    edit_path = email.text_part.body.to_s[%r{/password_resets/[^/\s]+/edit}]
    assert edit_path, "email should contain a reset link"

    get edit_path
    assert_response :success

    patch edit_path.delete_suffix("/edit"),
          params: { password: "newpass123", password_confirmation: "newpass123" }
    assert_redirected_to login_path
    assert @user.reload.authenticate("newpass123")
  end

  # --- edit / update ---------------------------------------------------

  test "edit with an invalid token redirects to login" do
    get edit_password_reset_path("not-a-real-token")
    assert_redirected_to login_path
  end

  test "edit with an expired token redirects to login" do
    token = issue_token

    travel User::RESET_TOKEN_TTL + 1.minute do
      get edit_password_reset_path(token)
      assert_redirected_to login_path
    end
  end

  test "a reset link only works once" do
    token = issue_token
    patch password_reset_path(token), params: { password: "newpass123", password_confirmation: "newpass123" }
    assert_redirected_to login_path

    get edit_password_reset_path(token)
    assert_redirected_to login_path
    assert_equal "That reset link is invalid or has expired.", flash[:alert]
  end

  test "update rejects a mismatched confirmation and keeps the link usable" do
    token = issue_token

    patch password_reset_path(token), params: { password: "newpass123", password_confirmation: "different" }

    assert_response :unprocessable_entity
    @user.reload
    assert @user.authenticate("password"), "old password should still work"
    assert_equal token, @user.reset_password_token
  end

  test "update rejects a blank password" do
    token = issue_token

    patch password_reset_path(token), params: { password: "", password_confirmation: "" }

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
  end

  test "update rejects a too-short password" do
    token = issue_token

    patch password_reset_path(token), params: { password: "abc", password_confirmation: "abc" }

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
  end

  private

  def issue_token
    @user.generate_reset_token!
    @user.reset_password_token
  end
end
