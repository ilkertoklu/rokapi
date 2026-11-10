import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "label" ]
  static values = { text: String, copied: String }

  #idleLabel
  #timer

  connect() {
    this.#idleLabel = this.labelTarget.textContent
    this.offer()
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  offer() {
    this.element.hidden = !(navigator.share || navigator.clipboard)
  }

  share() {
    if (navigator.share) {
      navigator.share({ text: this.textValue }).catch(() => {})
    } else {
      this.copy()
    }
  }

  copy() {
    navigator.clipboard?.writeText(this.textValue).then(() => this.#confirm()).catch(() => {})
  }

  #confirm() {
    clearTimeout(this.#timer)
    this.labelTarget.textContent = this.copiedValue
    this.#timer = setTimeout(() => this.labelTarget.textContent = this.#idleLabel, 2000)
  }
}
