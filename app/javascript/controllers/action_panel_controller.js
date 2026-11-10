import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "handle" ]

  connect() {
    if (this.#isPinnedOpen) {
      this.element.open = true
      this.handleTarget.tabIndex = -1
    }
  }

  get #isPinnedOpen() {
    return getComputedStyle(this.element).getPropertyValue("--action-panel-pinned").trim() === "open"
  }
}
