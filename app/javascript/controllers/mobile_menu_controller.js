import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "overlay"]

  connect() {
    // Close menu when clicking outside
    this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnClickOutside)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains("translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("translate-x-full")
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    // Add click outside listener after a short delay
    setTimeout(() => {
      document.addEventListener("click", this.boundCloseOnClickOutside)
    }, 100)
  }

  close() {
    this.menuTarget.classList.add("translate-x-full")
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("click", this.boundCloseOnClickOutside)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeMenu() {
    this.close()
  }
}
