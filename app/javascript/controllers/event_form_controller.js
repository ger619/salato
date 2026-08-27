import { Controller } from '@hotwired/stimulus';

// ── Pure helpers ──────────────────────────────────────────────────
// These don't touch instance state, so they live outside the class.

function slugify(value) {
  return value
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
}

function parseDate(value) {
  if (!value) return null;
  const date = new Date(value);
  // Number.isNaN does no coercion, so test the timestamp rather than the Date.
  return Number.isNaN(date.getTime()) ? null : date;
}

function sameDay(a, b) {
  return a.toDateString() === b.toDateString();
}

function formatDay(date) {
  return date.toLocaleDateString('en-KE', {
    weekday: 'short', day: 'numeric', month: 'short', year: 'numeric',
  });
}

function formatTime(date) {
  return date.toLocaleTimeString('en-KE', {
    hour: 'numeric', minute: '2-digit', hour12: true,
  });
}

function formatMoney(value) {
  return new Intl.NumberFormat('en-KE').format(value);
}

// ── Controller ────────────────────────────────────────────────────

export default class extends Controller {
  static targets = [
    'name', 'slug', 'description', 'venue', 'startAt', 'endAt', 'active',
    'count', 'dateWarning', 'status',
    'previewName', 'previewVenue', 'previewDate', 'previewSlug',
    'previewPrice', 'previewCapacity',
  ]

  static values = { slugTouched: Boolean }

  connect() {
    this.renderAll();
  }

  // ── Field handlers ──────────────────────────────────────────────

  nameChanged() {
    if (!this.slugTouchedValue && this.hasSlugTarget) {
      this.slugTarget.value = slugify(this.nameTarget.value);
    }
    this.renderName();
    this.renderSlug();
  }

  slugEdited() {
    this.slugTouchedValue = this.slugTarget.value.trim().length > 0;
    this.renderSlug();
  }

  descriptionChanged() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.descriptionTarget.value.length;
    }
  }

  venueChanged() {
    this.renderVenue();
  }

  startChanged() {
    if (this.hasEndAtTarget && this.startAtTarget.value) {
      this.endAtTarget.min = this.startAtTarget.value;
    }
    this.renderDate();
  }

  endChanged() {
    this.renderDate();
  }

  activeChanged() {
    this.renderStatus();
  }

  // Fired by tier inputs directly, and by ticket-tiers:changed when a row
  // is added or removed.
  tiersChanged() {
    this.renderTiers();
  }

  // ── Rendering ───────────────────────────────────────────────────

  renderAll() {
    this.renderName();
    this.renderSlug();
    this.renderVenue();
    this.renderDate();
    this.renderStatus();
    this.renderTiers();
    this.descriptionChanged();
    this.startChanged();
  }

  renderName() {
    if (!this.hasPreviewNameTarget) return;
    const name = this.hasNameTarget ? this.nameTarget.value.trim() : '';
    this.previewNameTarget.textContent = name || 'Untitled event';
  }

  renderSlug() {
    if (!this.hasPreviewSlugTarget) return;
    const slug = this.hasSlugTarget ? this.slugTarget.value.trim() : '';
    this.previewSlugTarget.textContent = slug || '…';
  }

  renderVenue() {
    if (!this.hasPreviewVenueTarget) return;
    const venue = this.hasVenueTarget ? this.venueTarget.value.trim() : '';
    this.previewVenueTarget.textContent = venue || 'Venue to be set';
  }

  renderDate() {
    const start = parseDate(this.hasStartAtTarget && this.startAtTarget.value);
    const end = parseDate(this.hasEndAtTarget && this.endAtTarget.value);

    if (this.hasDateWarningTarget) {
      const invalid = start && end && end < start;
      this.dateWarningTarget.classList.toggle('hidden', !invalid);
    }

    if (!this.hasPreviewDateTarget) return;

    if (!start) {
      this.previewDateTarget.textContent = 'Date to be set';
      return;
    }

    let text = `${formatDay(start)} · ${formatTime(start)}`;

    if (end) {
      text += sameDay(start, end)
        ? ` – ${formatTime(end)}`
        : ` → ${formatDay(end)}, ${formatTime(end)}`;
    }

    this.previewDateTarget.textContent = text;
  }

  renderStatus() {
    if (!this.hasStatusTarget) return;
    const live = this.hasActiveTarget ? this.activeTarget.checked : false;
    this.statusTarget.textContent = live ? 'On sale' : 'Draft';
    this.statusTarget.classList.toggle('text-white/70', !live);
    this.statusTarget.classList.toggle('text-white', live);
  }

  renderTiers() {
    const rows = Array.from(this.element.querySelectorAll('[data-tier]')).filter((row) => !row.hidden);

    const prices = rows
      .map((row) => parseFloat(row.querySelector('[data-tier-price]')?.value))
      .filter((value) => Number.isFinite(value) && value > 0);

    const capacity = rows
      .map((row) => parseInt(row.querySelector('[data-tier-quantity]')?.value, 10))
      .filter((value) => Number.isFinite(value) && value > 0)
      .reduce((total, value) => total + value, 0);

    if (this.hasPreviewPriceTarget) {
      this.previewPriceTarget.textContent = prices.length
        ? `From KES ${formatMoney(Math.min(...prices))}`
        : 'Price to be set';
    }

    if (this.hasPreviewCapacityTarget) {
      this.previewCapacityTarget.textContent = capacity
        ? `${formatMoney(capacity)} ${capacity === 1 ? 'ticket' : 'tickets'}`
        : 'No tickets yet';
    }
  }
}