import { Controller } from '@hotwired/stimulus';

const NAMES = { mpesa: 'M-Pesa', airtel: 'Airtel Money', card: 'card' };
const POLL_EVERY_MS = 5000;
const MAX_POLLS = 36; // about 3 minutes

export default class extends Controller {
  static targets = ['form', 'method', 'phoneField', 'phone', 'payButton', 'payLabel', 'error', 'waiting', 'waitingText']

  static values = {
    chargeUrl: String, cardUrl: String, statusUrl: String, amount: String,
  }

  connect() {
    this.select();
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  get method() {
    return this.methodTargets.find((input) => input.checked)?.value || 'mpesa';
  }

  select() {
    this.phoneFieldTarget.hidden = this.method === 'card';
    this.payLabelTarget.textContent = `Pay ${this.amountValue} with ${NAMES[this.method]}`;
    this.hideError();
  }

  async pay() {
    this.hideError();
    this.busy(true);

    try {
      if (this.method === 'card') {
        await this.payByCard();
      } else {
        await this.payByMobile();
      }
    } catch (_error) {
      this.showError('Something went wrong. Please try again.');
      this.busy(false);
    }
  }

  async payByMobile() {
    const phone = this.phoneTarget.value.trim();
    if (!phone) {
      this.showError('Enter the phone number to charge.');
      this.busy(false);
      return;
    }

    const body = await this.request(this.chargeUrlValue, { provider: this.method, phone });
    if (!body) return;

    if (body.status === 'paid') {
      window.location.href = body.redirect_url;
      return;
    }

    this.waitingTextTarget.textContent = body.message;
    this.formTarget.hidden = true;
    this.waitingTarget.hidden = false;
    this.poll(0);
  }

  async payByCard() {
    if (typeof PaystackPop === 'undefined') {
      this.showError("Card payment couldn't load. Refresh the page and try again.");
      this.busy(false);
      return;
    }

    const body = await this.request(this.cardUrlValue, {});
    if (!body) return;
    // eslint-disable-next-line
    new PaystackPop().resumeTransaction(body.access_code, {
      onSuccess: () => { window.location.href = body.callback_url; },
      onCancel: () => this.busy(false),
      onError: () => {
        this.showError('Card payment failed to load. Please try again.');
        this.busy(false);
      },
    });
  }

  poll(count) {
    if (count >= MAX_POLLS) {
      this.stopWaiting("We haven't received a confirmation yet. If you entered your PIN, your tickets will be emailed shortly. Otherwise, try again.");
      return;
    }

    this.timer = setTimeout(async () => {
      try {
        const response = await fetch(this.statusUrlValue, { headers: { Accept: 'application/json' } });
        const body = await response.json();

        if (body.status === 'paid' || body.status === 'closed') {
          window.location.href = body.redirect_url;
          return;
        }

        if (body.status === 'failed') {
          this.stopWaiting(body.error);
          return;
        }
      } catch (_error) {
        // Network blip: keep waiting.
      }

      this.poll(count + 1);
    }, POLL_EVERY_MS);
  }

  retry() {
    this.stopWaiting(null);
  }

  stopWaiting(message) {
    clearTimeout(this.timer);
    this.waitingTarget.hidden = true;
    this.formTarget.hidden = false;
    this.busy(false);
    if (message) this.showError(message);
  }

  // POSTs JSON; returns the parsed body, or null after handling an error.
  async request(url, payload) {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify(payload),
    });

    const body = await response.json();

    if (body.status === 'closed' && body.redirect_url) {
      window.location.href = body.redirect_url;
      return null;
    }

    if (!response.ok) {
      this.showError(body.error || 'Something went wrong. Please try again.');
      this.busy(false);
      return null;
    }

    return body;
  }

  busy(on) {
    this.payButtonTarget.disabled = on;
    this.methodTargets.forEach((input) => { input.disabled = on; });
  }

  showError(message) {
    this.errorTarget.textContent = message;
    this.errorTarget.hidden = false;
  }

  hideError() {
    this.errorTarget.hidden = true;
  }
}