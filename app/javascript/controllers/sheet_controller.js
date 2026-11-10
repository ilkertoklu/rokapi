import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sheet" ]
  static outlets = [ "stage" ]

  open() {
    this.sheetTarget.showModal()
  }

  close() {
    this.sheetTarget.close()
  }

  keepOpen(event) {
    if (event.detail.attributeName === "open") event.preventDefault()
  }

  returnFocus() {
    if (this.#focusIsLost && this.hasStageOutlet) this.stageOutlet.focus()
  }

  sheetTargetDisconnected() {
    this.returnFocus()
  }

  get #focusIsLost() {
    return document.activeElement === document.body || document.activeElement.getClientRects().length === 0
  }
}
