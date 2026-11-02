import { Controller } from "@hotwired/stimulus"
import { pluralize } from "helpers/pluralize"

export default class extends Controller {
  static targets = [ "input", "cell", "submit" ]
  static values = { length: Number, verify: String, digitsLeft: Object, rejected: String }

  connect() {
    this.update()
  }

  update() {
    const code = this.inputTarget.value
    const remaining = this.lengthValue - code.length
    const current = Math.min(code.length, this.lengthValue - 1)

    this.cellTargets.forEach((cell, index) => {
      cell.textContent = code[index] ?? ""
      cell.classList.toggle("code__cell--current", index === current)
    })

    this.submitTarget.disabled = remaining > 0
    this.submitTarget.value = remaining > 0 ? `${this.verifyValue} · ${pluralize(this.digitsLeftValue, remaining)}` : this.verifyValue
    this.element.classList.toggle("code-entry--rejected", this.rejectedValue !== "" && code === this.rejectedValue)
  }

  clear() {
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.update()
  }
}
