require "test_helper"

class BuyersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "should get index" do
    get buyers_path
    assert_response :success
  end

  test "should get new" do
    get new_buyer_path
    assert_response :success
  end

  test "should get show" do
    get buyer_path(buyers(:john))
    assert_response :success
  end
end
