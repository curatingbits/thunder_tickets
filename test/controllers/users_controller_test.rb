require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = sign_in
    @other = User.create!(name: "Other Person", email: "other@example.com",
                          password: "password", password_confirmation: "password")
  end

  test "can deactivate another user" do
    post toggle_active_user_path(@other)

    assert_redirected_to users_path
    refute @other.reload.active?
  end

  test "can reactivate another user" do
    @other.update!(active: false)

    post toggle_active_user_path(@other)

    assert @other.reload.active?
  end

  test "can't deactivate yourself via toggle" do
    post toggle_active_user_path(@admin)

    assert_redirected_to users_path
    assert_equal "You can't deactivate your own account.", flash[:alert]
    assert @admin.reload.active?
  end

  test "can't deactivate yourself via destroy" do
    delete user_path(@admin)

    assert_redirected_to users_path
    assert @admin.reload.active?
  end
end
