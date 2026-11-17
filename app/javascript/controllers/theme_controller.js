import { Controller } from "@hotwired/stimulus"

// Dark / Light / System picker. Saves the choice in the "theme" cookie, which
// the server reads to render <html data-theme>, and applies it right away.
// Charts listen for theme:change and repaint in the new colors.
// The two colors mirror ThemeHelper::THEME_COLORS.
const COLORS = { dark: "#16161e", light: "#eef0f5" }

export default class extends Controller {
  static targets = ["option"]

  select({ params: { choice } }) {
    document.cookie = `theme=${choice}; path=/; max-age=31536000; samesite=lax`
    document.documentElement.dataset.theme = choice
    this.updateThemeColor(choice)
    this.optionTargets.forEach((option) => {
      option.setAttribute("aria-pressed", String(option.dataset.themeChoiceParam === choice))
    })
    window.dispatchEvent(new CustomEvent("theme:change", { detail: { theme: choice } }))
  }

  updateThemeColor(choice) {
    document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => meta.remove())
    const add = (content, media) => {
      const meta = document.createElement("meta")
      meta.name = "theme-color"
      meta.content = content
      if (media) meta.media = media
      document.head.appendChild(meta)
    }
    if (choice === "system") {
      add(COLORS.light, "(prefers-color-scheme: light)")
      add(COLORS.dark, "(prefers-color-scheme: dark)")
    } else {
      add(COLORS[choice])
    }
  }
}
