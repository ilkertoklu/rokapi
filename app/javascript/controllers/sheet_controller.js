import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sheet" ]
  static classes = [ "open" ]

  open() {
    this.sheetTarget.classList.add(this.openClass)
  }

  close() {
    this.sheetTarget.classList.remove(this.openClass)
  }
}
