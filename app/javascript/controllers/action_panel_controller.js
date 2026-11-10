import { Controller } from "@hotwired/stimulus"
import { slide } from "helpers/slide"

const SWIPE_DISTANCE = 24

export default class extends Controller {
  static targets = [ "handle", "body" ]

  #grab = null
  #swiped = false
  #sight = new IntersectionObserver(([ entry ]) => this.element.toggleAttribute("data-out-of-view", !entry.isIntersecting))

  connect() {
    this.pin()
    this.#sight.observe(this.bodyTarget)
  }

  disconnect() {
    this.#sight.disconnect()
  }

  pin() {
    if (this.#isPinnedOpen) {
      this.element.open = true
      this.handleTarget.tabIndex = -1
    } else {
      this.handleTarget.removeAttribute("tabindex")
    }
  }

  keepState(event) {
    if ([ "open", "data-out-of-view" ].includes(event.detail.attributeName)) event.preventDefault()
  }

  toggle(event) {
    event.preventDefault()

    if (this.#swiped && event.detail) {
      this.#swiped = false
    } else if (this.element.open) {
      this.#close()
    } else {
      this.#open()
    }
  }

  grab(event) {
    this.#swiped = false
    if (!event.isPrimary) return

    this.#grab = { x: event.clientX, y: event.clientY }
    this.handleTarget.setPointerCapture(event.pointerId)
  }

  release(event) {
    if (!this.#grab) return

    const rise = this.#grab.y - event.clientY
    const drift = Math.abs(event.clientX - this.#grab.x)
    this.#grab = null

    if (Math.abs(rise) >= SWIPE_DISTANCE && Math.abs(rise) > drift) {
      this.#swiped = true
      if (rise > 0 && !this.element.open) this.#open()
      if (rise < 0 && this.element.open) this.#close()
    }
  }

  letGo() {
    this.#grab = null
  }

  #open() {
    this.element.open = true
    slide(this.element, { translate: [ `0 ${this.bodyTarget.offsetHeight}px`, "0 0" ] })
  }

  async #close() {
    await slide(this.element, { translate: [ "0 0", `0 ${this.bodyTarget.offsetHeight}px` ] })
    this.element.open = false
  }

  get #isPinnedOpen() {
    return getComputedStyle(this.element).getPropertyValue("--action-panel-pinned").trim() === "open"
  }
}
