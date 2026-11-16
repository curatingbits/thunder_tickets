import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    userId: Number
  }

  async copyInvitation(event) {
    event.preventDefault()

    const button = event.currentTarget
    const originalHTML = button.innerHTML

    try {
      // Fetch the invitation URL from the server
      const response = await fetch(`/users/${this.userIdValue}/invitation_url`)
      const data = await response.json()

      if (data.url) {
        // Copy to clipboard
        await navigator.clipboard.writeText(data.url)

        // Show success feedback
        // The colour goes on the icon, not the button: the button already
        // carries its own text colour class, and two competing colour
        // utilities resolve by stylesheet order, not by which was added last.
        button.innerHTML = `
          <svg class="h-5 w-5 text-positive" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
        `

        // Reset button after 2 seconds
        setTimeout(() => {
          button.innerHTML = originalHTML
        }, 2000)
      }
    } catch (error) {
      console.error("Failed to copy invitation link:", error)

      // Show error feedback
      button.innerHTML = `
        <svg class="h-5 w-5 text-negative" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      `

      // Reset button after 2 seconds
      setTimeout(() => {
        button.innerHTML = originalHTML
      }, 2000)
    }
  }
}
