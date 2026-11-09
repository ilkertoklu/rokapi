import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { openFrom: String }

  connect() {
    this.element.open = window.matchMedia(`(min-width: ${this.openFromValue})`).matches
  }
}
