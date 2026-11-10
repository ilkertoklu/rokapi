import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { step: String }

  stepValueChanged() {
    if (this.#focusIsLost) this.focus()
  }

  focus() {
    this.element.focus({ preventScroll: true })
  }

  get #focusIsLost() {
    return document.activeElement === document.body || this.element.contains(document.activeElement)
  }
}
