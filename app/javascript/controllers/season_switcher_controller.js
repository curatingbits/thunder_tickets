import { Controller } from "@hotwired/stimulus"

// Navigates to the selected season's dashboard when the dropdown changes.
export default class extends Controller {
  navigate(event) {
    const url = event.target.value
    if (url) {
      window.location.href = url
    }
  }
}
