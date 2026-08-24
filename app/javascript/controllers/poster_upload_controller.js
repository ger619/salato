import { Controller } from "@hotwired/stimulus"

// Drives the poster band on the event form: click or drag to pick a file,
// swap straight to a preview of it, and hand the file to the form's real
// <input type="file"> so it actually gets uploaded on submit.
//
// Connect with:
//   data-controller="poster-upload"
//   data-poster-upload-max-size-value="5242880"
export default class extends Controller {
  static targets = [
    "input", "zone", "preview", "image",
    "filename", "filesize", "dimensions",
    "error", "removeFlag"
  ]

  static values = {
    maxSize: { type: Number, default: 5 * 1024 * 1024 },
    accept: { type: String, default: "image/png,image/jpeg,image/webp" }
  }

  connect() {
    this.objectUrl = null
    this.dragDepth = 0
  }

  disconnect() {
    this.releaseObjectUrl()
  }

  // ── Picking a file ────────────────────────────────────────────────

  browse(event) {
    if (event) event.preventDefault()
    this.inputTarget.click()
  }

  fileChosen() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (file) this.accept(file)
  }

  // ── Drag and drop ─────────────────────────────────────────────────
  // dragleave fires when the pointer crosses onto a child element, so the
  // depth counter is what keeps the highlight from flickering.

  dragEnter(event) {
    event.preventDefault()
    this.dragDepth += 1
    this.zoneTarget.setAttribute("data-dragging", "")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dragDepth = Math.max(0, this.dragDepth - 1)
    if (this.dragDepth === 0) this.zoneTarget.removeAttribute("data-dragging")
  }

  drop(event) {
    event.preventDefault()
    this.dragDepth = 0
    this.zoneTarget.removeAttribute("data-dragging")

    const file = event.dataTransfer && event.dataTransfer.files[0]
    if (!file) return

    // Put the dropped file on the real input, otherwise the form submits empty.
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files

    this.accept(file)
  }

  // ── Removing ──────────────────────────────────────────────────────

  remove(event) {
    if (event) event.preventDefault()

    this.inputTarget.value = ""
    if (this.hasRemoveFlagTarget) this.removeFlagTarget.value = "1"

    this.releaseObjectUrl()
    this.imageTarget.removeAttribute("src")
    if (this.hasFilenameTarget) this.filenameTarget.textContent = ""
    if (this.hasFilesizeTarget) this.filesizeTarget.textContent = ""
    if (this.hasDimensionsTarget) this.dimensionsTarget.textContent = ""

    this.previewTarget.classList.add("hidden")
    this.zoneTarget.classList.remove("hidden")
    this.clearError()
    this.zoneTarget.focus()
  }

  // ── Preview ───────────────────────────────────────────────────────

  imageLoaded() {
    if (!this.hasDimensionsTarget) return
    const { naturalWidth: w, naturalHeight: h } = this.imageTarget
    this.dimensionsTarget.textContent = w && h ? ` · ${w}×${h}` : ""
  }

  accept(file) {
    const problem = this.validate(file)
    if (problem) {
      this.inputTarget.value = ""
      this.showError(problem)
      return
    }

    this.clearError()
    if (this.hasRemoveFlagTarget) this.removeFlagTarget.value = "0"

    this.releaseObjectUrl()
    this.objectUrl = URL.createObjectURL(file)
    this.imageTarget.src = this.objectUrl

    if (this.hasFilenameTarget) this.filenameTarget.textContent = file.name
    if (this.hasFilesizeTarget) this.filesizeTarget.textContent = this.humanSize(file.size)
    if (this.hasDimensionsTarget) this.dimensionsTarget.textContent = ""

    this.zoneTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")

    this.dispatch("changed", { detail: { name: file.name, url: this.objectUrl } })
  }

  validate(file) {
    const allowed = this.acceptValue.split(",").map((type) => type.trim())

    if (!allowed.includes(file.type)) {
      return "That file isn't a JPG, PNG or WebP. Pick an image in one of those formats."
    }
    if (file.size > this.maxSizeValue) {
      return `That image is ${this.humanSize(file.size)}. The limit is ${this.humanSize(this.maxSizeValue)} — try exporting it smaller.`
    }
    return null
  }

  // ── Helpers ───────────────────────────────────────────────────────

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  releaseObjectUrl() {
    if (!this.objectUrl) return
    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    const mb = bytes / (1024 * 1024)
    return mb >= 1 ? `${mb.toFixed(1)} MB` : `${Math.round(bytes / 1024)} KB`
  }
}
