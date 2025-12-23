import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="game-form"
export default class extends Controller {
  static targets = ["gameType", "roundSelect", "roundContainer"]

  static values = {
    playoffRounds: Array,
    nbaCupRounds: Array
  }

  connect() {
    this.updateRoundOptions()
  }

  updateRoundOptions() {
    const gameType = this.gameTypeTarget.value
    const roundSelect = this.roundSelectTarget
    const roundContainer = this.roundContainerTarget

    // Clear existing options
    roundSelect.innerHTML = '<option value="">Select round</option>'

    let rounds = []
    if (gameType === "playoff") {
      rounds = this.playoffRoundsValue
      roundContainer.classList.remove("hidden")
    } else if (gameType === "nba_cup") {
      rounds = this.nbaCupRoundsValue
      roundContainer.classList.remove("hidden")
    } else {
      roundContainer.classList.add("hidden")
      return
    }

    rounds.forEach(round => {
      const option = document.createElement("option")
      option.value = round
      option.textContent = round
      roundSelect.appendChild(option)
    })
  }
}
