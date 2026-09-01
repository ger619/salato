import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['startButton', 'stage', 'video', 'canvas', 'status']

  static values = { input: String, form: String }

  disconnect() { this.stopCamera(); }

  async start() {
    if (!navigator.mediaDevices?.getUserMedia) {
      this.setStatus("This browser can't use the camera. Type the number instead.");
      return;
    }

    this.startButtonTarget.classList.add('hidden');
    this.stageTarget.classList.remove('hidden');
    this.setStatus('Point the camera at the QR code.');

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: 'environment' } },
        audio: false,
      });
    } catch (error) {
      // eslint-disable-next-line
      console.error('[qr-scanner] camera denied:', error);
      this.reset();
      this.setStatus('Camera blocked. Allow access, or type the ticket number.');
      return;
    }

    const video = this.videoTarget;
    video.srcObject = this.stream;
    video.muted = true;
    video.setAttribute('playsinline', '');

    try {
      await video.play();
      // eslint-disable-next-line
    } catch (error) {
      // eslint-disable-next-line
      console.error('[qr-scanner] video.play() failed:', error);
      this.reset();
      this.setStatus("Couldn't start the preview. Type the ticket number instead.");
      return;
    }

    await this.prepareDecoder();

    this.scanning = true;
    this.loop();
  }

  async prepareDecoder() {
    // eslint-disable-next-line
    if ('BarcodeDetector' in window) {
      try {
        // eslint-disable-next-line
        this.detector = new BarcodeDetector({ formats: ['qr_code'] });
        return;
        // eslint-disable-next-line
      } catch (error) {
        console.warn('[qr-scanner] BarcodeDetector unavailable:', error);
      }
    }
    // eslint-disable-next-line
    try {
      const module = await import('jsqr');
      // eslint-disable-next-line
      this.jsQR = module.default;
    } catch (error) {
      console.error('[qr-scanner] jsQR failed to load:', error);
      this.setStatus("Scanning isn't available here. Type the ticket number.");
    }
  }

  cancel() {
    this.reset();
    this.setStatus('');
  }

  loop() {
    // eslint-disable-next-line
    if (!this.scanning) return;
    // eslint-disable-next-line
    this.readFrame()
      .then((value) => { if (value) this.submit(value); })
      .catch((error) => console.error('[qr-scanner] frame error:', error))
      .finally(() => {
        if (this.scanning) this.timer = setTimeout(() => this.loop(), 150);
      });
  }

  async readFrame() {
    const video = this.videoTarget;
    if (video.readyState < video.HAVE_ENOUGH_DATA) return null;

    if (this.detector) {
      const codes = await this.detector.detect(video);
      return codes[0]?.rawValue ?? null;
    }

    if (!this.jsQR) return null;

    const canvas = this.canvasTarget;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    if (!canvas.width || !canvas.height) return null;

    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    const frame = ctx.getImageData(0, 0, canvas.width, canvas.height);
    return this.jsQR(frame.data, frame.width, frame.height,
      { inversionAttempts: 'dontInvert' })?.data ?? null;
  }

  submit(value) {
    this.scanning = false;
    this.stopCamera();
    // eslint-disable-next-line
    this.setStatus('Looking up the ticket…');
    // eslint-disable-next-line
    const input = document.querySelector(this.inputValue);
    const form = document.querySelector(this.formValue);
    if (!input || !form) {
      console.error('[qr-scanner] missing input or form:', this.inputValue, this.formValue);
      return;
    }

    input.value = value.trim();
    form.requestSubmit();
  }

  reset() {
    this.stopCamera();
    this.stageTarget.classList.add('hidden');
    this.startButtonTarget.classList.remove('hidden');
  }

  stopCamera() {
    this.scanning = false;
    if (this.timer) { clearTimeout(this.timer); this.timer = null; }
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
    if (this.hasVideoTarget) this.videoTarget.srcObject = null;
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text;
  }
}