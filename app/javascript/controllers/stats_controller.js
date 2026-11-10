import { Controller } from "@hotwired/stimulus"
import { pluralize } from "helpers/pluralize"

export default class extends Controller {
  static targets = [ "value", "increment", "decrement", "remaining", "submit", "label" ]
  static values = { free: Number, cap: Number, bases: Object, klass: String, ready: String, pointsLeft: Object }
  static classes = [ "raised" ]

  connect() {
    this.#render()
  }

  increment({ params: { key } }) {
    if (this.#canRaise(key)) this.#adjust(key, +1)
  }

  decrement({ params: { key } }) {
    if (this.#canLower(key)) this.#adjust(key, -1)
  }

  rebase({ params: { klass } }) {
    this.klassValue = klass
    this.valueTargets.forEach(input => input.value = this.#base(input.dataset.key))
    this.#render()
  }

  #adjust(key, delta) {
    const input = this.#input(key)
    input.value = parseInt(input.value) + delta
    this.#render()
  }

  #canRaise(key) {
    return this.#remaining() > 0 && this.#value(key) < this.capValue
  }

  #canLower(key) {
    return this.#value(key) > this.#base(key)
  }

  #input(key) {
    return this.valueTargets.find(el => el.dataset.key === key)
  }

  #value(key) {
    return parseInt(this.#input(key).value)
  }

  #base(key) {
    return this.basesValue[this.klassValue][key]
  }

  #remaining() {
    return this.freeValue - this.valueTargets.reduce(
      (spent, input) => spent + parseInt(input.value) - this.#base(input.dataset.key), 0
    )
  }

  #pointsLeft(remaining) {
    return pluralize(this.pointsLeftValue, remaining)
  }

  #render() {
    const remaining = this.#remaining()
    this.remainingTarget.textContent = this.#pointsLeft(remaining)
    this.valueTargets.forEach((input, row) => {
      const key = input.dataset.key
      input.classList.toggle(this.raisedClass, this.#canLower(key))
      this.incrementTargets[row].disabled = !this.#canRaise(key)
      this.decrementTargets[row].disabled = !this.#canLower(key)
    })
    this.submitTarget.disabled = remaining !== 0
    this.labelTarget.textContent = remaining === 0 ? this.readyValue : `${this.readyValue} · ${this.#pointsLeft(remaining)}`
  }
}
