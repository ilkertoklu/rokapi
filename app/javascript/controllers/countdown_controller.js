import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "timer" ]
  static values = { seconds: { type: Number, default: 45 } }

  connect() {
    this.remaining = this.secondsValue
    this.buttonTarget.disabled = true
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    if (this.remaining <= 0) {
      clearInterval(this.interval)
      this.buttonTarget.disabled = false
      this.timerTarget.textContent = ""
    } else {
      const minutes = Math.floor(this.remaining / 60)
      const seconds = String(this.remaining % 60).padStart(2, "0")
      this.timerTarget.textContent = ` · ${minutes}:${seconds}`
      this.remaining--
    }
  }
}
