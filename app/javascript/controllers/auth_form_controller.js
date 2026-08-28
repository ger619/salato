import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['submit', 'label', 'error', 'errorText', 'password']

  static values = {
    idleLabel: { type: String, default: 'Sign in' },
    busyLabel: { type: String, default: 'Signing in…' },
  }

  async submit(event) {
    event.preventDefault();

    this.hideError();
    this.setBusy(true);

    try {
      const response = await fetch(event.target.action, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': this.csrfToken,
        },
        body: new FormData(event.target),
      });

      const data = await this.parse(response);

      if (response.ok) {
        window.location.assign(data.location || '/');
        return;
      }

      this.showError(data.error || 'Something went wrong. Try again.');
      this.resetPassword();
    } catch {
      this.showError("Couldn't reach the server. Check your connection.");
    } finally {
      this.setBusy(false);
    }
  }

  // ---- helpers ----

  // eslint-disable-next-line
  async parse(response) {
    try {
      return await response.json();
    } catch {
      return {};
    }
  }

  setBusy(busy) {
    this.submitTarget.disabled = busy;
    this.labelTarget.textContent = busy ? this.busyLabelValue : this.idleLabelValue;
  }

  showError(message) {
    this.errorTextTarget.textContent = message;
    this.errorTarget.classList.remove('hidden');
  }

  hideError() {
    this.errorTarget.classList.add('hidden');
  }

  resetPassword() {
    if (!this.hasPasswordTarget) return;

    this.passwordTarget.value = '';
    this.passwordTarget.focus();
  }
  // eslint-disable-next-line
  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content;
  }
}