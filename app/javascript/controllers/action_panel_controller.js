import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "handle" ]

  connect() {
    this.pin()
  }

  pin() {
    if (this.#isPinnedOpen) {
      this.element.open = true
      this.handleTarget.tabIndex = -1
    } else {
      this.handleTarget.removeAttribute("tabindex")
    }
  }

  keepOpen(event) {
    if (event.detail.attributeName === "open") event.preventDefault()
  }

  get #isPinnedOpen() {
    return getComputedStyle(this.element).getPropertyValue("--action-panel-pinned").trim() === "open"
  }
}
