import { Controller } from "@hotwired/stimulus"

// The sign-in form: shows or hides the password, warns while Caps Lock is on,
// and clears a failed attempt's error as soon as someone types again. Every
// message goes in the one line under the password, which keeps its height, so
// nothing on the page moves.
export default class extends Controller {
  static targets = [ "field", "password", "reveal", "message", "caps" ]

  connect() {
    this.error = this.messageTarget.innerHTML
    this.showingError = this.messageTarget.dataset.tone === "error"
    this.capsOn = false
  }

  reveal() {
    const hidden = this.passwordTarget.type === "password"
    this.passwordTarget.type = hidden ? "text" : "password"
    this.revealTarget.setAttribute("aria-pressed", String(hidden))
    this.revealTarget.setAttribute("aria-label", hidden ? "Hide password" : "Show password")
    this.revealTarget.querySelectorAll("svg").forEach((svg) => svg.classList.toggle("hidden"))
    this.passwordTarget.focus({ preventScroll: true })
  }

  caps(event) {
    if (typeof event.getModifierState !== "function") return
    const on = event.getModifierState("CapsLock")
    if (on === this.capsOn) return
    this.capsOn = on
    this.render()
  }

  // Typing again means the last attempt's error no longer applies.
  edit() {
    if (!this.showingError) return
    this.showingError = false
    this.fieldTargets.forEach((field) => field.removeAttribute("aria-invalid"))
    this.render()
  }

  render() {
    const line = this.messageTarget
    if (this.capsOn) {
      line.dataset.tone = "caps"
      line.innerHTML = this.capsTarget.innerHTML
    } else if (this.showingError) {
      line.dataset.tone = "error"
      line.innerHTML = this.error
    } else {
      line.dataset.tone = ""
      line.innerHTML = ""
    }
  }
}
