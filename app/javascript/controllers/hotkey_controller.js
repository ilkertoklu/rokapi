import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  click(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault()
      this.element.click()
    }
  }

  get #isClickable() {
    return this.#isRendered && !this.element.disabled && !this.#isBehindModal
  }

  get #isRendered() {
    return this.element.checkVisibility?.() ?? this.element.getClientRects().length > 0
  }

  get #isBehindModal() {
    const modal = document.querySelector("dialog:modal")
    return modal && !modal.contains(this.element)
  }

  #shouldIgnore(event) {
    return event.repeat || event.target.closest("input, select, textarea, [contenteditable]") || this.#activatesFocused(event)
  }

  #activatesFocused(event) {
    return event.key === "Enter" && event.target.closest("a, button, summary")
  }
}
