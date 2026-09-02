import { Controller } from "@hotwired/stimulus"

// Wrap a single password field. Swaps the input between password and text,
// and swaps the eye icon to match.
export default class extends Controller {
  static targets = ["input", "button", "eyeOpen", "eyeClosed"]

  toggle() {
    const revealed = this.inputTarget.type === "text"

    // Preserve the caret so the toggle doesn't send it to the end.
    const caret = this.inputTarget.selectionStart

    this.inputTarget.type = revealed ? "password" : "text"

    this.eyeOpenTarget.classList.toggle("hidden", revealed)
    this.eyeClosedTarget.classList.toggle("hidden", !revealed)

    this.buttonTarget.setAttribute("aria-pressed", String(!revealed))
    this.buttonTarget.setAttribute(
      "aria-label",
      revealed ? "Show password" : "Hide password"
    )

    this.inputTarget.focus()
    if (caret !== null) this.inputTarget.setSelectionRange(caret, caret)
  }
}
