import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "deck", "card", "dot" ]
  static classes = [ "current" ]

  #sight = new IntersectionObserver(entries => {
    if (this.#isScrollable) {
      entries.filter(entry => entry.isIntersecting).forEach(entry => entry.target.control.checked = true)
    }
    this.#markCurrentDot()
  }, { root: this.deckTarget, threshold: .9 })

  cardTargetConnected(card) {
    this.#sight.observe(card)
  }

  cardTargetDisconnected(card) {
    this.#sight.unobserve(card)
  }

  bring({ target }) {
    this.#show(target.closest("label"))
  }

  restore() {
    this.#show(this.cardTargets.find(card => card.control.checked))
  }

  #show(card) {
    card?.scrollIntoView({ block: "nearest", inline: "nearest" })
    this.#markCurrentDot()
  }

  get #isScrollable() {
    return this.deckTarget.scrollWidth > this.deckTarget.clientWidth
  }

  #markCurrentDot() {
    this.dotTargets.forEach((dot, index) => dot.classList.toggle(this.currentClass, this.cardTargets[index].control.checked))
  }
}
