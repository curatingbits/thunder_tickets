import { Controller } from "@hotwired/stimulus"

// Dismiss button on a flash message (replaces an inline onclick).
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
