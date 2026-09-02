import { Controller } from "@hotwired/stimulus"

// Shows and hides the Lexxy formatting toolbar. The actual hiding is a CSS
// rule keyed off data-collapsed on this element, so we don't have to wait for
// Lexxy to finish bootstrapping its toolbar before we can touch it.
export default class extends Controller {
  static targets = ["button", "label", "chevron"]
  static values  = { collapsed: { type: Boolean, default: true } }

  toggle() {
    this.collapsedValue = !this.collapsedValue
  }

  // Fires on connect too, so the initial state is set for free.
  collapsedValueChanged() {
    this.element.dataset.collapsed = String(this.collapsedValue)

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", String(!this.collapsedValue))
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.collapsedValue ? "Formatting" : "Hide formatting"
    }

    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-180", !this.collapsedValue)
    }
  }
}
