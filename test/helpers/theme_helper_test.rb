require "test_helper"

class ThemeHelperTest < ActionView::TestCase
  test "dark unless the cookie names a known theme" do
    assert_equal "dark", current_theme
    cookies[:theme] = "light"
    assert_equal "light", current_theme
    cookies[:theme] = "neon"
    assert_equal "dark", current_theme
  end

  test "one theme-color for a fixed theme, one per OS setting for system" do
    cookies[:theme] = "light"
    assert_dom_equal '<meta name="theme-color" content="#eef0f5">', theme_color_meta_tags

    cookies[:theme] = "system"
    tags = Nokogiri::HTML.fragment(theme_color_meta_tags).css("meta")
    assert_equal [ "(prefers-color-scheme: light)", "(prefers-color-scheme: dark)" ], tags.map { |t| t["media"] }
  end
end
