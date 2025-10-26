import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ticket-form"
export default class extends Controller {
  connect() {
    console.log("✅ Ticket form controller connected!")
  }

  // Intercept form submission
  submit(event) {
    console.log("🎫 Ticket form submit handler called")
    console.log("Event type:", event.type)
    console.log("Event target:", event.target)

    // Find the buyer select field directly (avoiding nested controller issues)
    const buyerSelect = this.element.querySelector('select[name="ticket[buyer_id]"]')

    if (!buyerSelect) {
      console.log("⚠️ Buyer select not found, allowing submission")
      return
    }

    const buyerValue = buyerSelect.value
    console.log("Buyer value:", buyerValue)

    // Check if user has "Create New Buyer" selected
    if (buyerValue === "new") {
      console.log("❌ Blocking submission - 'new' buyer selected")
      event.preventDefault()
      event.stopPropagation()

      alert("Please create the buyer first using the form below, or select an existing buyer from the dropdown.")

      // Scroll to buyer section
      buyerSelect.scrollIntoView({ behavior: 'smooth', block: 'center' })
      buyerSelect.focus()
      return
    }

    console.log("✅ Allowing form submission - buyer value is valid")
    // If buyer is valid or empty, allow form to submit normally
    // (by not calling preventDefault, the event continues)
  }
}
