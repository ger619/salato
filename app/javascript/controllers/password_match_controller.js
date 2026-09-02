import { Controller } from "@hotwired/stimulus"

// Compares the two password fields as they're typed and blocks the wizard's
// Continue button while they differ. The server still validates — this is
// only here so nobody gets to step two and back for a typo.
export default class extends Controller {
  static targets = ["password", "confirmation", "message", "submit"]
  static values  = { minLength: { type: Number, default: 6 } }

  connect() { this.check() }

  check() {
    const password     = this.passwordTarget.value
    const confirmation = this.confirmationTarget.value

    if (password.length === 0 && confirmation.length === 0) {
      return this.reset()
    }

    if (password.length > 0 && password.length < this.minLengthValue) {
      return this.fail(`Use at least ${this.minLengthValue} characters.`)
    }

    if (confirmation.length === 0) {
      return this.reset()
    }

    if (password === confirmation) {
      return this.pass("Passwords match.")
    }

    this.fail("Passwords don't match yet.")
  }

  pass(text) {
    this.render(text, "text-emerald-600")
    this.confirmationTarget.setCustomValidity("")
    this.allowContinue(true)
  }

  fail(text) {
    this.render(text, "text-[#E13765]")
    this.confirmationTarget.setCustomValidity(text)
    this.allowContinue(false)
  }

  reset() {
    this.render("", "")
    this.confirmationTarget.setCustomValidity("")
    this.allowContinue(true)
  }

  render(text, colourClass) {
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = text
    this.messageTarget.classList.remove("text-emerald-600", "text-[#E13765]")
    if (colourClass) this.messageTarget.classList.add(colourClass)
  }

  allowContinue(allowed) {
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = !allowed
    this.submitTarget.classList.toggle("opacity-50", !allowed)
    this.submitTarget.classList.toggle("cursor-not-allowed", !allowed)
  }
}
