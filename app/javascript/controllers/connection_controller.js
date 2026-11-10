import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = [ "source", "dialog" ]
  static values = { grace: { type: Number, default: 2000 } }

  #subscribed = false
  #timer = null
  #watch = new MutationObserver(() => this.#update())

  disconnect() {
    this.#watch.disconnect()
    clearTimeout(this.#timer)
  }

  sourceTargetConnected(source) {
    this.#watch.observe(source, { attributeFilter: [ "connected" ] })
    this.#update()
  }

  async retry() {
    const consumer = await cable.getConsumer()
    consumer.connection.reopen()
  }

  stayOpen(event) {
    event.preventDefault()
  }

  #update() {
    if (this.#streaming) {
      clearTimeout(this.#timer)
      this.#timer = null
      this.#subscribed = true
      if (this.dialogTarget.open) this.#resume()
    } else if (this.#subscribed && !this.#timer && !this.dialogTarget.open) {
      this.#timer = setTimeout(() => this.#pause(), this.graceValue)
    }
  }

  #pause() {
    this.#timer = null
    this.dialogTarget.showModal()
  }

  #resume() {
    this.dialogTarget.close()
    Turbo.visit(window.location.href, { action: "replace" })
  }

  get #streaming() {
    return this.sourceTargets.length > 0 && this.sourceTargets.every(source => source.hasAttribute("connected"))
  }
}
