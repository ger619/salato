import { Controller } from '@hotwired/stimulus';

// A unique index for each new nested record, so Rails doesn't collapse two
// rows added in the same millisecond into one.
function nextIndex() {
  return `${Date.now()}${Math.floor(Math.random() * 1000)}`;
}

// Adds and removes ticket tier rows in the event form.
//
// New rows are cloned from a <template>; the NEW_RECORD placeholder in the
// field names is swapped for a unique index so Rails treats each one as a
// separate nested record. Rows that already exist in the database aren't
// deleted from the DOM — they're hidden and flagged with _destroy, so the
// removal only takes effect when the form is saved.
export default class extends Controller {
  static targets = ['list', 'template', 'row', 'rowLabel', 'removeButton', 'empty']

  connect() {
    if (this.visibleRows.length === 0) this.add();
    this.refresh();
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, nextIndex());
    this.listTarget.insertAdjacentHTML('beforeend', html);
    this.refresh();

    const added = this.visibleRows[this.visibleRows.length - 1];
    added?.querySelector('input[type=text]')?.focus();
  }

  remove(event) {
    const row = event.target.closest('[data-tier]');
    if (!row) return;

    const destroyField = row.querySelector('[data-tier-destroy]');
    const persisted = row.querySelector("input[name*='[id]']");

    if (persisted && destroyField) {
      destroyField.value = '1';
      row.hidden = true;
    } else {
      row.remove();
    }

    this.refresh();
  }

  // ── Housekeeping ────────────────────────────────────────────────

  refresh() {
    const rows = this.visibleRows;

    rows.forEach((row, index) => {
      const label = row.querySelector("[data-ticket-tiers-target='rowLabel']");
      if (label) label.textContent = `Tier ${index + 1}`;
    });

    // Never let the organiser delete the last tier — an event with no
    // tickets can't sell anything.
    rows.forEach((row) => {
      const button = row.querySelector("[data-ticket-tiers-target='removeButton']");
      if (button) button.disabled = rows.length === 1;
    });

    this.dispatch('changed', { detail: { count: rows.length } });
  }

  get visibleRows() {
    return Array.from(this.element.querySelectorAll('[data-tier]')).filter((row) => !row.hidden);
  }
}