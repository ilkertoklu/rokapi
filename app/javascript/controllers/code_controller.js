import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "cell", "submit" ]
  static values = { length: Number }

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
    this.submitTarget.value = remaining > 0 ? `Verify · ${remaining} digit${remaining === 1 ? "" : "s"} left` : "Verify"
  }
}
