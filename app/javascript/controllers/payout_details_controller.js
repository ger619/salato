import { Controller } from "@hotwired/stimulus"

// Shows the Bank or Mobile money select based on "Payout type".
// Hidden selects are also disabled, so they are not required and not submitted.
export default class extends Controller {
  static targets = ["method", "bank", "mobileMoney"]

  connect() {
    this.toggle()
  }

  toggle() {
    const method = this.methodTarget.value
    this.#show(this.bankTarget, method === "bank")
    this.#show(this.mobileMoneyTarget, method === "mobile_money")
  }

  #show(wrapper, visible) {
    wrapper.hidden = !visible
    wrapper.querySelectorAll("select, input").forEach((el) => (el.disabled = !visible))
  }
}