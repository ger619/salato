import { Controller } from '@hotwired/stimulus';

// Copies the event URL and confirms it in the button itself, so there's no
// toast to dismiss. Falls back to a text selection on older browsers.
export default class extends Controller {
  static targets = ['label', 'button']

  static values = { url: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlValue);
    } catch {
      const field = document.createElement('textarea');
      field.value = this.urlValue;
      field.setAttribute('readonly', '');
      field.style.position = 'fixed';
      field.style.opacity = '0';
      document.body.appendChild(field);
      field.select();
      document.execCommand('copy');
      field.remove();
    }

    this.confirm();
  }

  confirm() {
    const original = this.labelTarget.textContent;
    this.labelTarget.textContent = 'Link copied';
    this.buttonTarget.classList.add('text-magenta', 'ring-magenta/40');

    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.labelTarget.textContent = original;
      this.buttonTarget.classList.remove('text-magenta', 'ring-magenta/40');
    }, 2000);
  }

  disconnect() {
    clearTimeout(this.timer);
  }
}