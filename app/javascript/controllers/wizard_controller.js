// app/javascript/controllers/wizard_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['step', 'indicator', 'preview'];

  connect() {
    this.index = this.errorStep();
    this.render();
  }

  // ── navigation ──────────────────────────────────────────────

  next() {
    if (!this.validateStep(this.index)) return;
    this.go(Math.min(this.index + 1, this.lastIndex));
  }

  back() {
    this.go(Math.max(this.index - 1, 0));
  }

  // used by the "Edit" links on the review step:
  //   data-action="wizard#edit" data-wizard-step-param="0"
  edit(event) {
    this.go(Number(event.params.step ?? 0));
  }

  go(i) {
    this.index = i;
    if (this.isPreview) this.fillPreview();
    this.render();
  }

  // ── submit guard ────────────────────────────────────────────
  // Steps 1 and 2 are hidden when the submit button is on step 3.
  // A required field inside a hidden div blocks submission but the
  // browser cannot focus it, so we find it ourselves and jump back.
  onSubmit(event) {
    for (let i = 0; i < this.stepTargets.length; i += 1) {
      const invalid = this.invalidFieldIn(i);
      // eslint-disable-next-line
      if (!invalid) continue;

      event.preventDefault();
      this.go(i);
      // wait for the step to become visible before reporting
      requestAnimationFrame(() => {
        invalid.focus();
        invalid.reportValidity();
      });
      return;
    }
  }

  // ── preview ─────────────────────────────────────────────────

  fillPreview() {
    this.previewTargets.forEach((el) => {
      const ids = (el.dataset.previewSource || '').split(' ').filter(Boolean);
      const value = ids
        .map((id) => (document.getElementById(id)?.value || '').trim())
        .filter(Boolean)
        .join(' ');

      el.textContent = value || 'Not provided';
      el.classList.toggle('text-[#150D3A]/35', !value);
      el.classList.toggle('italic', !value);
    });
  }

  // ── rendering ───────────────────────────────────────────────

  render() {
    this.stepTargets.forEach((el, i) => el.classList.toggle('hidden', i !== this.index));

    this.indicatorTargets.forEach((el, i) => {
      const active = i === this.index;
      const done = i < this.index;
      el.classList.toggle('text-[#7620B1]', active);
      el.classList.toggle('text-[#7620B1]/55', done);
      el.classList.toggle('text-gray-400', !active && !done);
    });

    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // ── helpers ─────────────────────────────────────────────────

  get lastIndex() {
    return this.stepTargets.length - 1;
  }

  get isPreview() {
    return this.index === this.lastIndex;
  }

  fieldsIn(i) {
    return Array.from(this.stepTargets[i].querySelectorAll('input, select, textarea'));
  }

  invalidFieldIn(i) {
    return this.fieldsIn(i).find((field) => !field.checkValidity());
  }

  validateStep(i) {
    const invalid = this.invalidFieldIn(i);
    if (!invalid) return true;

    invalid.focus();
    invalid.reportValidity();
    return false;
  }

  errorStep() {
    const step = Number(this.element.dataset.wizardErrorStep);
    return Number.isNaN(step) ? 0 : step;
  }
}