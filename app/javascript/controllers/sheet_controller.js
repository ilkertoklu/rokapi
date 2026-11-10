import { Controller } from "@hotwired/stimulus"
import { slide } from "helpers/slide"

const CLOSING_SHARE = 1 / 3
const CLOSING_SPEED = 0.5

export default class extends Controller {
  static targets = [ "sheet", "scrim", "panel" ]
  static outlets = [ "stage" ]

  #drag = null
  #dragged = false

  open() {
    this.sheetTarget.showModal()
    this.#glide(this.#height, 0)
  }

  async close() {
    await this.#glide(0, this.#height)
    this.sheetTarget.close()
  }

  dismiss(event) {
    event.preventDefault()
    this.close()
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

  grab(event) {
    this.#dragged = false
    if (event.isPrimary && this.sheetTarget.matches(":modal") && this.#canDragFrom(event)) {
      this.#drag = { x: event.clientX, y: event.clientY, at: event.timeStamp, offset: 0, speed: 0, following: false }
    }
  }

  drag(event) {
    if (this.#drag && !this.#drag.following) this.#decide(event)
    if (!this.#drag?.following) return

    const drag = this.#drag
    const offset = Math.max(0, event.clientY - drag.y)
    drag.speed = (offset - drag.offset) / Math.max(1, event.timeStamp - drag.at)
    drag.offset = offset
    drag.at = event.timeStamp
    this.#follow(offset)
  }

  holdPage(event) {
    if (this.#drag?.following && event.cancelable) event.preventDefault()
  }

  release(event) {
    const drag = this.#drag
    this.#drag = null
    if (!drag?.following) return

    this.#dragged = true
    this.#follow(null)
    if (event.type === "pointerup" && (drag.offset > this.#height * CLOSING_SHARE || drag.speed > CLOSING_SPEED)) {
      this.#glide(drag.offset, this.#height).then(() => this.sheetTarget.close())
    } else {
      this.#glide(drag.offset, 0)
    }
  }

  ignoreClickAfterDrag(event) {
    if (this.#dragged && event.detail) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.#dragged = false
  }

  #canDragFrom(event) {
    return event.target.closest(".sheet__handle") || (event.pointerType !== "mouse" && this.panelTarget.scrollTop <= 0)
  }

  #decide(event) {
    const down = event.clientY - this.#drag.y
    const across = Math.abs(event.clientX - this.#drag.x)

    if (down > across) {
      this.#drag.following = true
      this.panelTarget.setPointerCapture(event.pointerId)
    } else if (down < 0 || across > 0) {
      this.#drag = null
    }
  }

  #follow(offset) {
    this.panelTarget.style.translate = offset === null ? "" : `0 ${offset}px`
    this.scrimTarget.style.opacity = offset === null ? "" : 1 - offset / this.#height
  }

  #glide(from, to) {
    const height = this.#height
    return Promise.all([
      slide(this.panelTarget, { translate: [ `0 ${from}px`, `0 ${to}px` ] }),
      slide(this.scrimTarget, { opacity: [ 1 - from / height, 1 - to / height ] })
    ])
  }

  get #height() {
    return this.panelTarget.offsetHeight
  }

  get #focusIsLost() {
    return document.activeElement === document.body || document.activeElement.getClientRects().length === 0
  }
}
