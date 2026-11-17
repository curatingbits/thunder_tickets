require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  setup { sign_in }

  test "pricing thresholds can be changed and cleared back to defaults" do
    patch pricing_settings_path, params: { settings: { "pricing.overpriced_pct" => "20", "pricing.seller_fee_pct" => "" } }
    assert_redirected_to settings_path
    assert_equal BigDecimal("20"), AppSetting.get("pricing.overpriced_pct")
    assert_nil AppSetting.get("pricing.seller_fee_pct")

    patch pricing_settings_path, params: { settings: { "pricing.overpriced_pct" => "" } }
    assert_equal 15, AppSetting.get("pricing.overpriced_pct")
  end

  test "non-numbers are refused" do
    patch pricing_settings_path, params: { settings: { "pricing.overpriced_pct" => "lots" } }
    assert_equal "Those settings need numbers.", flash[:alert]
  end

  test "tokens are listed by name and prefix only, and can be revoked" do
    token, raw = ApiToken.generate!(name: "market-research", scopes: [ "market:write" ])

    get settings_path
    assert_response :success
    assert_match "market-research", response.body
    assert_match token.token_prefix, response.body
    assert_no_match raw, response.body

    delete api_token_path(token)
    assert token.reload.revoked_at.present?
  end

  test "the seat row is editable" do
    patch settings_path, params: { season: { seat_section: "101", seat_row: "EE" } }
    assert_equal "EE", seasons(:current).reload.seat_row
  end
end
