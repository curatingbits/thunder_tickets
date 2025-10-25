require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get seasons_edit_url
    assert_response :success
  end

  test "should get update" do
    get seasons_update_url
    assert_response :success
  end
end
