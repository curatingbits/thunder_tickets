import { Controller } from "@hotwired/stimulus"

// A flash message. The dismiss button removes it. Optionally it fades out
// (fade) and dismisses itself after a timeout in ms, as the sign-in page's
// notices do.
export default class extends Controller {
  static values = { timeout: Number, fade: Boolean }

  connect() {
    if (this.timeoutValue > 0) this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    clearTimeout(this.timer)
    if (!this.fadeValue || matchMedia("(prefers-reduced-motion: reduce)").matches) return this.element.remove()
    this.element.classList.add("is-leaving")
    setTimeout(() => this.element.remove(), 300)
  }
}
