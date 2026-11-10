import { Controller } from "@hotwired/stimulus"
import { pluralize } from "helpers/pluralize"

export default class extends Controller {
  static targets = [ "input", "cell", "submit" ]
  static values = { length: Number, verify: String, digitsLeft: Object, rejected: String }
  static classes = [ "current", "rejected" ]

  connect() {
    this.update()
  }

  update() {
    const code = this.inputTarget.value
    const remaining = this.lengthValue - code.length
    const current = Math.min(code.length, this.lengthValue - 1)

    this.cellTargets.forEach((cell, index) => {
      cell.textContent = code[index] ?? ""
      cell.classList.toggle(this.currentClass, index === current)
    })

    this.submitTarget.disabled = remaining > 0
    this.submitTarget.value = remaining > 0 ? `${this.verifyValue} · ${pluralize(this.digitsLeftValue, remaining)}` : this.verifyValue
    if (this.hasRejectedClass) this.element.classList.toggle(this.rejectedClass, this.rejectedValue !== "" && code === this.rejectedValue)
  }

  clear() {
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.update()
  }
}
