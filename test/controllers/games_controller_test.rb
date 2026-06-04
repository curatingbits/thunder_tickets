require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @game = games(:current_past)
  end

  test "should get index" do
    get games_path
    assert_response :success
  end

  test "should get new" do
    get new_game_path
    assert_response :success
  end

  test "should get show" do
    get game_path(@game)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_path(@game)
    assert_response :success
  end
end
