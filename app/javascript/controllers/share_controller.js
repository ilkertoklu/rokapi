import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "label" ]
  static values = { text: String, copied: String }

  connect() {
    this.element.hidden = !(navigator.share || navigator.clipboard)
    this.idleLabel = this.labelTarget.textContent
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  share() {
    if (navigator.share) {
      navigator.share({ text: this.textValue }).catch(() => {})
    } else if (navigator.clipboard) {
      navigator.clipboard.writeText(this.textValue).then(() => this.confirm()).catch(() => {})
    }
  }

  confirm() {
    clearTimeout(this.timer)
    this.labelTarget.textContent = this.copiedValue
    this.timer = setTimeout(() => this.labelTarget.textContent = this.idleLabel, 2000)
  }
}
