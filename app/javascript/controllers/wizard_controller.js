// app/javascript/controllers/wizard_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['step', 'indicator']

  connect() {
    this.index = this.hasErrorOnStepTwo() ? 1 : 0;
    this.render();
  }

  next() {
    const current = this.stepTargets[this.index];
    const fields = current.querySelectorAll('input, select, textarea');
    // eslint-disable-next-line
    for (const field of fields) {
      if (!field.checkValidity()) {
        field.reportValidity();
        return;
      }
    }

    this.index = 1;
    this.render();
  }

  back() {
    this.index = 0;
    this.render();
  }

  render() {
    this.stepTargets.forEach((el, i) => el.classList.toggle('hidden', i !== this.index));
    this.indicatorTargets.forEach((el, i) => {
      el.classList.toggle('text-[#7620B1]', i === this.index);
      el.classList.toggle('text-gray-400', i !== this.index);
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  hasErrorOnStepTwo() {
    return this.element.dataset.wizardErrorStep === '2';
  }
}