import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { grace: { type: Number, default: 2000 } }

  connect() {
    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(document.body, { subtree: true, attributeFilter: [ "connected" ] })
    this.update()
  }

  disconnect() {
    this.observer.disconnect()
    clearTimeout(this.timer)
  }

  update() {
    if (this.streaming) {
      clearTimeout(this.timer)
      this.timer = null
      this.subscribed = true
      if (this.element.open) this.resume()
    } else if (this.subscribed && !this.timer && !this.element.open) {
      this.timer = setTimeout(() => this.pause(), this.graceValue)
    }
  }

  async retry() {
    const consumer = await cable.getConsumer()
    consumer.connection.reopen()
  }

  stayOpen(event) {
    event.preventDefault()
  }

  pause() {
    this.timer = null
    this.element.showModal()
  }

  resume() {
    this.element.close()
    Turbo.visit(window.location.href, { action: "replace" })
  }

  get streaming() {
    const sources = document.querySelectorAll("turbo-cable-stream-source")
    return sources.length > 0 && Array.from(sources).every(source => source.hasAttribute("connected"))
  }
}
