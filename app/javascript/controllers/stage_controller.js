import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { step: String }

  stepValueChanged() {
    if (this.#mayTakeFocus) this.focus()
  }

  focus() {
    this.element.focus({ preventScroll: true })
  }

  get #mayTakeFocus() {
    return document.activeElement === document.body || this.element.contains(document.activeElement)
  }
}
