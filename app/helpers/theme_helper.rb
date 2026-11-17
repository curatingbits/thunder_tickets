module ThemeHelper
  THEMES = %w[dark light system].freeze
  DEFAULT_THEME = "dark".freeze

  # Browser chrome color for each theme (the canvas token's value).
  THEME_COLORS = { "dark" => "#16161e", "light" => "#eef0f5" }.freeze

  # The theme picked in the theme picker, kept in a cookie so the server can
  # render <html data-theme> and the first paint is already right.
  def current_theme
    THEMES.include?(cookies[:theme]) ? cookies[:theme] : DEFAULT_THEME
  end

  # "system" needs one tag per OS setting; the browser picks by media query.
  def theme_color_meta_tags
    if current_theme == "system"
      safe_join([
        tag.meta(name: "theme-color", content: THEME_COLORS["light"], media: "(prefers-color-scheme: light)"),
        tag.meta(name: "theme-color", content: THEME_COLORS["dark"], media: "(prefers-color-scheme: dark)")
      ])
    else
      tag.meta(name: "theme-color", content: THEME_COLORS.fetch(current_theme))
    end
  end
end
