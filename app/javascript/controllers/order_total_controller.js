import { Controller } from "@hotwired/stimulus"

// Keeps the order summary in step with the quantity field. The server still
// recalculates the real total — this is display only, so a tampered DOM
// can't change what anyone is charged.
export default class extends Controller {
  static targets = ["quantity", "count", "total", "minus", "plus", "limit"]
  static values = { unitPrice: Number, max: Number }

  connect() {
    this.formatter = new Intl.NumberFormat("en-KE")
    this.recalculate()
  }

  increment() { this.nudge(1) }
  decrement() { this.nudge(-1) }

  nudge(step) {
    this.quantityTarget.value = this.clamp(this.currentQuantity + step)
    this.recalculate()
  }

  recalculate() {
    const quantity = this.clamp(this.currentQuantity)

    // Don't fight the user mid-typing — only rewrite the field if it's out of range.
    if (String(quantity) !== this.quantityTarget.value) {
      this.quantityTarget.value = quantity
    }

    this.countTarget.textContent = quantity
    this.totalTarget.textContent = `KES ${this.formatter.format(quantity * this.unitPriceValue)}`

    this.minusTarget.disabled = quantity <= 1
    this.plusTarget.disabled = quantity >= this.maxValue

    if (this.hasLimitTarget) {
      this.limitTarget.textContent =
          quantity >= this.maxValue ? `${this.maxValue} is the most per order` : `${this.maxValue} per order`
    }
  }

  get currentQuantity() {
    return parseInt(this.quantityTarget.value, 10) || 1
  }

  clamp(value) {
    return Math.min(Math.max(value, 1), this.maxValue)
  }
}