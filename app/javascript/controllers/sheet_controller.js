import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sheet" ]

  open() {
    this.sheetTarget.showModal()
  }

  close() {
    this.sheetTarget.close()
  }

  keepOpen(event) {
    if (event.detail.attributeName === "open") event.preventDefault()
  }
}
