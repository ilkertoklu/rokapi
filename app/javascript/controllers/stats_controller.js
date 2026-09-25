import { Controller } from "@hotwired/stimulus"
import { pluralize } from "helpers/pluralize"

export default class extends Controller {
  static targets = [ "value", "increment", "decrement", "remaining", "submit" ]
  static values = { free: Number, cap: Number, bases: Object, klass: String, ready: String, pointsLeft: Object }

  connect() {
    this.render()
  }

  increment(event) {
    if (this.canRaise(event.params.key)) this.adjust(event.params.key, +1)
  }

  decrement(event) {
    if (this.canLower(event.params.key)) this.adjust(event.params.key, -1)
  }

  rebase(event) {
    this.klassValue = event.params.klass
    this.valueTargets.forEach(input => input.value = this.base(input.dataset.key))
    this.render()
  }

  adjust(key, delta) {
    const input = this.input(key)
    input.value = parseInt(input.value) + delta
    this.render()
  }

  canRaise(key) {
    return this.remaining() > 0 && this.value(key) < this.capValue
  }

  canLower(key) {
    return this.value(key) > this.base(key)
  }

  input(key) {
    return this.valueTargets.find(el => el.dataset.key === key)
  }

  value(key) {
    return parseInt(this.input(key).value)
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
    return pluralize(this.pointsLeftValue, remaining)
  }

  render() {
    const remaining = this.remaining()
    this.remainingTarget.textContent = this.pointsLeft(remaining)
    this.valueTargets.forEach(input => {
      input.classList.toggle("stat-row__value--raised", this.canLower(input.dataset.key))
    })
    this.incrementTargets.forEach(button => button.disabled = !this.canRaise(button.dataset.statsKeyParam))
    this.decrementTargets.forEach(button => button.disabled = !this.canLower(button.dataset.statsKeyParam))
    this.submitTarget.disabled = remaining !== 0
    this.submitTarget.value = remaining === 0 ? this.readyValue : `${this.readyValue} · ${this.pointsLeft(remaining)}`
  }
}
