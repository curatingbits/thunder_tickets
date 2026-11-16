require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "signed_currency puts the sign before the dollar sign" do
    assert_equal "+$1,234", signed_currency(1234)
    assert_equal "-$390", signed_currency(-390)
  end

  test "signed_currency shows zero without a sign" do
    assert_equal "$0", signed_currency(0)
  end

  test "signed_currency takes the sign from the rounded value" do
    assert_equal "$0", signed_currency(-0.4)
    assert_equal "$0", signed_currency(BigDecimal("0.49"))
    assert_equal "-$1", signed_currency(-0.5)
  end

  test "signed_currency handles BigDecimal money and optional cents" do
    assert_equal "-$69.67", signed_currency(BigDecimal("-69.666"), precision: 2)
    assert_equal "+$80", signed_currency(BigDecimal("80.0"))
  end
end
