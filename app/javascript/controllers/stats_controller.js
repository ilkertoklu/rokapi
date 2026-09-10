import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "value", "remaining", "submit" ]
  static values = { free: Number, cap: Number, bases: Object, klass: String }

  connect() {
    this.render()
  }

  increment(event) {
    this.adjust(event.params.key, +1)
  }

  decrement(event) {
    this.adjust(event.params.key, -1)
  }

  rebase(event) {
    this.klassValue = event.params.klass
    this.valueTargets.forEach(input => input.value = this.base(input.dataset.key))
    this.render()
  }

  adjust(key, delta) {
    const input = this.valueTargets.find(el => el.dataset.key === key)
    const next = parseInt(input.value) + delta

    if (next < this.base(key) || next > this.capValue) return
    if (delta > 0 && this.remaining() <= 0) return

    input.value = next
    this.render()
  }

  base(key) {
    return this.basesValue[this.klassValue][key]
  }

  remaining() {
    return this.freeValue - this.valueTargets.reduce(
      (spent, input) => spent + parseInt(input.value) - this.base(input.dataset.key), 0
    )
  }

  pointsLeft(remaining) {
    return `${remaining} point${remaining === 1 ? "" : "s"} left`
  }

  render() {
    const remaining = this.remaining()
    this.remainingTarget.textContent = `· ${this.pointsLeft(remaining)}`
    this.submitTarget.disabled = remaining !== 0
    this.submitTarget.value = remaining === 0 ? "I'm ready" : `I'm ready · ${this.pointsLeft(remaining)}`
  }
}
