import { Controller } from "@hotwired/stimulus"

// Switches between the single-sale and bulk-sale forms on the game page.
// Tab styling comes from data-bulk-sale-{active,inactive}-tab-class on the
// element, so the class names live in the view with the rest of the design
// tokens instead of being hardcoded here.
export default class extends Controller {
  static targets = ["singleTab", "bulkTab", "singleForm", "bulkForm", "totalAmount", "pricePreview"]
  static values = { availableCount: Number }
  static classes = ["activeTab", "inactiveTab"]

  connect() {
    this.updatePreview()
  }

  showSingle(event) {
    event.preventDefault()
    this.activate(this.singleTabTarget, this.bulkTabTarget)
    this.singleFormTarget.classList.remove("hidden")
    this.bulkFormTarget.classList.add("hidden")
  }

  showBulk(event) {
    event.preventDefault()
    this.activate(this.bulkTabTarget, this.singleTabTarget)
    this.bulkFormTarget.classList.remove("hidden")
    this.singleFormTarget.classList.add("hidden")
  }

  activate(activeTab, inactiveTab) {
    activeTab.classList.remove(...this.inactiveTabClasses)
    activeTab.classList.add(...this.activeTabClasses)
    inactiveTab.classList.remove(...this.activeTabClasses)
    inactiveTab.classList.add(...this.inactiveTabClasses)
  }

  updatePreview() {
    const total = parseFloat(this.totalAmountTarget.value) || 0
    const count = this.availableCountValue

    if (total > 0 && count > 0) {
      const perTicket = (total / count).toFixed(2)
      this.pricePreviewTarget.textContent = `Recording ${count} ticket${count > 1 ? 's' : ''} at $${perTicket} each`
      this.pricePreviewTarget.classList.remove("hidden")
    } else {
      this.pricePreviewTarget.classList.add("hidden")
    }
  }
}
