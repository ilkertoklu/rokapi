import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "submit" ]
  static values = { length: Number }

  connect() {
    this.update()
  }

  update() {
    const remaining = this.lengthValue - this.inputTarget.value.length
    this.submitTarget.disabled = remaining > 0
    this.submitTarget.value = remaining > 0 ? `Doğrula · ${remaining} hane kaldı` : "Doğrula"
  }
}
