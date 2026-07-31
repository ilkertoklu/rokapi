import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "description" ]

  show(event) {
    this.descriptionTargets.forEach(el => el.hidden = el.dataset.key !== event.target.value)
  }
}
