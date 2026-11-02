import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "submit" ]
  static values = { word: String }

  connect() {
    this.update()
  }

  update() {
    this.submitTarget.disabled = comparable(this.inputTarget.value) !== comparable(this.wordValue)
  }
}

function comparable(word) {
  return word.trim().normalize("NFD").replace(/\p{M}/gu, "").toUpperCase()
}
