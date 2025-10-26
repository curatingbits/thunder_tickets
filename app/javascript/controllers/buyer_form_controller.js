import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="buyer-form"
export default class extends Controller {
  static targets = ["select", "formContainer", "formFields", "nameInput", "emailInput", "errorContainer", "errorList"]

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
    this.hideErrors()
  }

  hideForm() {
    this.formContainerTarget.classList.add("hidden")
    this.clearForm()
    this.hideErrors()
  }

  clearForm() {
    if (this.hasNameInputTarget) {
      this.nameInputTarget.value = ""
    }
    if (this.hasEmailInputTarget) {
      this.emailInputTarget.value = ""
    }
  }

  hideErrors() {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.classList.add("hidden")
    }
  }

  showErrors(errors) {
    if (this.hasErrorContainerTarget && this.hasErrorListTarget) {
      this.errorListTarget.innerHTML = errors.map(err => `<li>${err}</li>`).join("")
      this.errorContainerTarget.classList.remove("hidden")
    }
  }

  cancelForm(event) {
    event.preventDefault()
    this.selectTarget.value = ""
    this.hideForm()
  }

  // Submit buyer via fetch API (not nested form)
  async submitBuyerForm(event) {
    event.preventDefault()
    event.stopPropagation()

    const name = this.nameInputTarget.value.trim()
    const email = this.emailInputTarget.value.trim()

    // Basic validation
    if (!name) {
      this.showErrors(["Name can't be blank"])
      return
    }

    // Get CSRF token from meta tag
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch("/buyers", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          buyer: {
            name: name,
            email: email,
            inline: "true"
          }
        })
      })

      const data = await response.json()

      if (response.ok && data.buyer) {
        const buyer = data.buyer

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
      } else {
        // Handle validation errors
        const errors = data.errors || ["Failed to create buyer"]
        this.showErrors(errors)
      }
    } catch (error) {
      console.error("Error creating buyer:", error)
      this.showErrors(["Network error. Please try again."])
    }
  }
}
