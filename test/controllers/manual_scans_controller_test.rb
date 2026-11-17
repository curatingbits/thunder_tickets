require "test_helper"

class ManualScansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @game = games(:current_future)
  end

  test "pasted listings become a manual snapshot" do
    post game_manual_scans_path(@game), params: { listings_text: "101,MM,200\n101,KK,210\n101,LL,190\n101,EE,260\n120,DD,240" }

    assert_redirected_to game_path(@game)
    snapshot = @game.market_snapshots.sole
    assert_equal "manual", snapshot.import_run.source
    assert_equal "completed", snapshot.import_run.status
    assert_equal 5, snapshot.captured_count
    assert_equal 3, snapshot.confidence_breakdown["coverage"]
  end

  test "nothing recognizable is refused" do
    post game_manual_scans_path(@game), params: { listings_text: "hello" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /No listings found/
  end
end
