import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="buyer-form"
export default class extends Controller {
  static targets = ["select", "formContainer", "form"]

  connect() {
    // Hide form initially
    this.hideForm()
  }

  toggleForm() {
    if (this.selectTarget.value === "new") {
      this.showForm()
    } else {
      this.hideForm()
    }
  }

  showForm() {
    this.formContainerTarget.classList.remove("hidden")
  }

  hideForm() {
    this.formContainerTarget.classList.add("hidden")
    // Reset form if it exists
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
  }

  // Called when buyer is successfully created
  handleSuccess(event) {
    const [data, status, xhr] = event.detail

    // Parse the response to get buyer data
    const response = JSON.parse(xhr.response)

    if (response.buyer) {
      const buyer = response.buyer

      // Add new buyer to dropdown (before the "Create New Buyer" option)
      const newOption = new Option(
        buyer.email ? `${buyer.name} (${buyer.email})` : buyer.name,
        buyer.id,
        false,
        true // selected
      )

      // Find the "Create New Buyer" option and insert before it
      const createNewOption = this.selectTarget.querySelector('option[value="new"]')
      if (createNewOption) {
        this.selectTarget.insertBefore(newOption, createNewOption)
      } else {
        this.selectTarget.add(newOption)
      }

      // Select the new buyer
      this.selectTarget.value = buyer.id

      // Hide and reset the form
      this.hideForm()
    }
  }

  // Called when form submission fails
  handleError(event) {
    // Errors will be shown in the form itself via Rails
    console.error("Failed to create buyer")
  }
}
