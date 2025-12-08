import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["singleTab", "bulkTab", "singleForm", "bulkForm", "totalAmount", "pricePreview"]
  static values = { availableCount: Number }

  connect() {
    this.updatePreview()
  }

  showSingle(event) {
    event.preventDefault()
    this.singleTabTarget.classList.add("bg-blue-600", "text-white")
    this.singleTabTarget.classList.remove("bg-gray-700", "text-gray-300")
    this.bulkTabTarget.classList.remove("bg-blue-600", "text-white")
    this.bulkTabTarget.classList.add("bg-gray-700", "text-gray-300")
    this.singleFormTarget.classList.remove("hidden")
    this.bulkFormTarget.classList.add("hidden")
  }

  showBulk(event) {
    event.preventDefault()
    this.bulkTabTarget.classList.add("bg-blue-600", "text-white")
    this.bulkTabTarget.classList.remove("bg-gray-700", "text-gray-300")
    this.singleTabTarget.classList.remove("bg-blue-600", "text-white")
    this.singleTabTarget.classList.add("bg-gray-700", "text-gray-300")
    this.bulkFormTarget.classList.remove("hidden")
    this.singleFormTarget.classList.add("hidden")
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
