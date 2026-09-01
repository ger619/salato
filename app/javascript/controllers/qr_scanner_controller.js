// app/javascript/controllers/qr_scanner_controller.js
//
// Opens the rear camera, watches for a QR code, and drops the result into
// the manual-entry field then submits it — so the server-side verification
// path is exactly the same whether the code was scanned or typed.
//
// Requires HTTPS. getUserMedia is blocked on plain http:// everywhere
// except localhost, so this will silently fail on a LAN IP in development.
//
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['video', 'canvas', 'stage', 'status', 'startButton'];

  static values = {
    input: String, // CSS selector for the manual-entry text field
    form: String, // CSS selector for the form to submit
  };

  connect() {
    this.stream = null;
    this.detector = null;
    this.scanning = false;
    this.lastResult = null;
  }

  disconnect() {
    this.stop();
  }

  // ── start / stop ────────────────────────────────────────────

  async start() {
    if (this.scanning) return;

    if (!navigator.mediaDevices?.getUserMedia) {
      this.setStatus('This browser cannot open the camera. Type the number instead.', true);
      return;
    }

    this.setStatus('Starting camera…');

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: 'environment' } },
        audio: false,
      });
    } catch (error) {
      this.setStatus(this.permissionMessage(error), true);
      return;
    }

    const video = this.videoTarget;
    video.srcObject = this.stream;
    video.setAttribute('playsinline', true); // iOS refuses fullscreen-less video without this
    await video.play();

    this.stageTarget.classList.remove('hidden');
    this.startButtonTarget.classList.add('hidden');
    this.setStatus('Point the camera at the QR code.');

    this.detector = await this.buildDetector();
    this.scanning = true;
    this.tick();
  }

  stop() {
    this.scanning = false;

    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }

    if (this.hasVideoTarget) this.videoTarget.srcObject = null;
    if (this.hasStageTarget) this.stageTarget.classList.add('hidden');
    if (this.hasStartButtonTarget) this.startButtonTarget.classList.remove('hidden');
  }

  cancel() {
    this.stop();
    this.setStatus('');
  }

  // ── the scan loop ───────────────────────────────────────────

  async tick() {
    if (!this.scanning) return;

    const video = this.videoTarget;

    if (video.readyState === video.HAVE_ENOUGH_DATA) {
      try {
        const value = await this.detector(video);
        if (value && value !== this.lastResult) {
          this.lastResult = value;
          this.handleResult(value);
          return;
        }
      } catch (error) {
        // a single dropped frame is not worth stopping over
        // eslint-disable-next-line
        console.debug('scan frame failed', error);
      }
    }

    requestAnimationFrame(() => this.tick());
  }

  handleResult(raw) {
    this.setStatus('Ticket found — checking…');

    if (navigator.vibrate) navigator.vibrate(80);
    this.stop();

    const code = this.extractCode(raw);
    const input = document.querySelector(this.inputValue);
    const form = document.querySelector(this.formValue);

    if (!input || !form) {
      this.setStatus(`Scanned ${code}, but the form is missing.`, true);
      return;
    }

    input.value = code;
    form.requestSubmit();
  }

  // QR codes often hold a full URL rather than a bare number.
  // https://salato.co.ke/t/ABC-12345  →  ABC-12345
  // eslint-disable-next-line
  extractCode(raw) {
    try {
      const url = new URL(raw);
      const segments = url.pathname.split('/').filter(Boolean);
      return segments[segments.length - 1] || raw;
    } catch {
      return raw.trim();
    }
  }

  // ── detector: native first, jsQR as fallback ────────────────

  async buildDetector() {
    if ('BarcodeDetector' in window) {
      try {
        const formats = await window.BarcodeDetector.getSupportedFormats();
        if (formats.includes('qr_code')) {
          const native = new window.BarcodeDetector({ formats: ['qr_code'] });
          return async (video) => {
            const [first] = await native.detect(video);
            return first?.rawValue || null;
          };
        }
      } catch {
        // fall through to jsQR
      }
    }

    const { default: jsQR } = await import('jsqr');
    const canvas = this.canvasTarget;
    const context = canvas.getContext('2d', { willReadFrequently: true });

    return async (video) => {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      context.drawImage(video, 0, 0, canvas.width, canvas.height);

      const image = context.getImageData(0, 0, canvas.width, canvas.height);
      const result = jsQR(image.data, image.width, image.height, {
        inversionAttempts: 'dontInvert',
      });

      return result?.data || null;
    };
  }

  // ── helpers ─────────────────────────────────────────────────
  // eslint-disable-next-line
  permissionMessage(error) {
    switch (error.name) {
      case 'NotAllowedError':
        return 'Camera access was blocked. Allow it in your browser settings, or type the number.';
      case 'NotFoundError':
        return 'No camera found on this device.';
      case 'NotReadableError':
        return 'The camera is in use by another app.';
      default:
        return 'Could not start the camera. Type the number instead.';
    }
  }

  setStatus(message, isError = false) {
    if (!this.hasStatusTarget) return;
    this.statusTarget.textContent = message;
    this.statusTarget.classList.toggle('text-pink', isError);
    this.statusTarget.classList.toggle('text-ink2', !isError);
  }
}