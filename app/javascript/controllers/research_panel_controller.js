import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The research panel on Pricing (research_requests/_panel), on its
// turbo-frame. While an update waits, starts or runs, it re-reads the panel
// every few seconds. When research that was going finishes, it reloads the
// page so the board shows the new prices. A hidden tab doesn't poll.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 15000 } }

  connect() {
    this.lastState = this.state
    this.loaded = () => this.frameLoaded()
    this.shown = () => (document.hidden ? this.stop() : this.schedule(0))
    this.element.addEventListener("turbo:frame-load", this.loaded)
    document.addEventListener("visibilitychange", this.shown)
    this.schedule()
  }

  disconnect() {
    this.stop()
    this.element.removeEventListener("turbo:frame-load", this.loaded)
    document.removeEventListener("visibilitychange", this.shown)
  }

  get state() {
    return this.element.querySelector("[data-research-state]")?.dataset.researchState ?? "idle"
  }

  frameLoaded() {
    const was = this.lastState
    this.lastState = this.state
    if ((was === "running" || was === "starting") && this.state === "idle") {
      Turbo.visit(window.location.href, { action: "replace" })
    } else {
      this.schedule()
    }
  }

  schedule(delay = this.intervalValue) {
    this.stop()
    if (this.state === "idle" || document.hidden) return
    this.timer = setTimeout(() => this.refresh(), delay)
  }

  stop() {
    clearTimeout(this.timer)
  }

  refresh() {
    if (this.element.getAttribute("src") === this.urlValue) {
      this.element.reload()
    } else {
      this.element.src = this.urlValue
    }
  }
}
