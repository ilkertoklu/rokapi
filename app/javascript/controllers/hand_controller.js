import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "deck", "card", "dot" ]
  static classes = [ "current" ]

  connect() {
    this.observer = new IntersectionObserver(entries => {
      if (this.#isScrollable) {
        entries.filter(entry => entry.isIntersecting).forEach(entry => entry.target.control.checked = true)
      }
      this.#markCurrentDot()
    }, { root: this.deckTarget, threshold: .9 })

    this.cardTargets.forEach(card => this.observer.observe(card))
  }

  disconnect() {
    this.observer.disconnect()
  }

  bring({ target }) {
    target.closest("label").scrollIntoView({ block: "nearest", inline: "nearest" })
    this.#markCurrentDot()
  }

  get #isScrollable() {
    return this.deckTarget.scrollWidth > this.deckTarget.clientWidth
  }

  #markCurrentDot() {
    this.dotTargets.forEach((dot, index) => dot.classList.toggle(this.currentClass, this.cardTargets[index].control.checked))
  }
}
