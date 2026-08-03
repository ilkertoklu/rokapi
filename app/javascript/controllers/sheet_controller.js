import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sheet" ]

  open() {
    this.sheetTarget.hidden = false
  }

  close() {
    this.sheetTarget.hidden = true
  }
}
