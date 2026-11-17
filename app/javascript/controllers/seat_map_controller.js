import { Controller } from "@hotwired/stimulus"

// The seat map on Pricing (pricing/_seat_map). The list of listings is the real control and works on its own; the 3D
// view (arena3d/viewer, loaded here by a dynamic import so no other page pays for three.js) follows it, and a tap on a
// seat picks the matching listings in the list. Choosing a game swaps a frame inside this element; the 3D stage is
// data-turbo-permanent, so the same view takes the new game's data instead of being rebuilt.
//
// As with Invintory's 3D fridge, the WebGL context is let go whenever the page isn't on screen and made again when it's
// back, Turbo's preview of a cached page never starts one, and without WebGL the list carries on alone with a note.
// window.__seatMap is a handle for the system tests.
export default class extends Controller {
  static targets = [ "stage", "data", "list", "item", "status", "note", "noteText", "retry", "form", "controls" ]
  static values = { venue: Object }

  connect() {
    this.generation = 0
    this.selected ||= []
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.scheme = window.matchMedia("(prefers-color-scheme: light)")
    // Choosing a game swaps a frame and moves the address on (data-turbo-action="advance"), which caches the page as
    // if leaving it. The 3D view stays through that; it goes when a visit leaves this page.
    this.listen(document, "turbo:visit", (event) => {
      this.staying = new URL(event.detail.url, location.href).pathname === location.pathname
    })
    this.listen(document, "turbo:before-cache", () => {
      if (!this.staying) this.stop()
      this.staying = false
    })
    this.listen(document, "visibilitychange", () => {
      if (document.visibilityState === "visible") this.start()
      else this.stop()
    })
    this.listen(window, "pagehide", () => this.stop())
    this.listen(window, "pageshow", (event) => { if (event.persisted) this.start() })
    this.listen(window, "theme:change", () => this.repaint())
    this.listen(this.scheme, "change", () => this.repaint())
    this.listen(this.element, "turbo:frame-load", () => this.frameLoaded())
    window.__seatMap = this.hook()

    if (document.documentElement.hasAttribute("data-turbo-preview")) {
      this.listen(document, "turbo:load", () => this.start(), { once: true })
    } else {
      this.start()
    }
  }

  disconnect() {
    this.stop()
    for (const [ target, type, handler ] of this.listeners || []) target.removeEventListener(type, handler)
    this.listeners = []
    if (window.__seatMap?.controller === this) window.__seatMap = null
  }

  listen(target, type, handler, options) {
    (this.listeners ||= []).push([ target, type, handler ])
    target.addEventListener(type, handler, options)
  }

  // A game's data: on the first render, and each time the game changes.
  dataTargetConnected(element) {
    this.gameData = JSON.parse(element.dataset.json)
    this.selected = []
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
    this.paintSwatches()
    this.viewer?.setData(this.gameData)
    if (this.viewer) this.showControls(true)
    if (this.generation != null && !this.viewer) this.start()
  }

  async start() {
    if (this.viewer || this.starting || this.failed || !this.hasStageTarget || !this.gameData) return
    if (document.visibilityState === "hidden" || document.documentElement.hasAttribute("data-turbo-preview")) return
    this.starting = true
    const generation = ++this.generation
    this.stageTarget.classList.remove("hidden")
    try {
      const { createViewer } = await import("arena3d/viewer")
      if (generation !== this.generation || !this.element.isConnected) return
      try {
        this.viewer = createViewer(this.stageTarget, {
          venue: this.venueValue, colors: this.colors(), reducedMotion: this.reducedMotion.matches,
          onSelect: (ids) => this.select(ids, { from: "map" }),
          onLost: () => this.fail("The 3D view stopped: the browser wanted its memory back. The list still has every listing.", { retry: true })
        })
      } catch (error) {
        return this.fail("This browser can't show the 3D view (it needs WebGL 2). The list below has every listing.", { retry: false, error })
      }
      this.viewer.setData(this.gameData)
      if (this.selected.length) this.viewer.select(this.selected)
      this.element.dataset.seatMapState = "ready"
      this.showControls(true)
    } catch (error) {
      if (generation === this.generation) this.fail("The 3D view didn't load. The list below has every listing.", { retry: true, error })
    } finally {
      if (generation === this.generation) this.starting = false
    }
  }

  showControls(on) {
    if (!this.hasControlsTarget) return
    this.controlsTarget.classList.toggle("hidden", !on)
    this.controlsTarget.classList.toggle("inline-flex", on)
  }

  // Lets go of the scene and its WebGL context; the selection stays for the next start.
  stop() {
    this.generation = (this.generation || 0) + 1
    this.starting = false
    this.viewer?.dispose()
    this.viewer = null
    if (this.element.dataset.seatMapState === "ready") delete this.element.dataset.seatMapState
  }

  fail(message, { retry, error } = {}) {
    if (error) console.warn("seat map 3D:", error)
    this.stop()
    this.failed = true
    this.stageTarget.classList.add("hidden")
    this.showControls(false)
    this.noteTextTarget.textContent = message
    this.retryTarget.hidden = !retry
    this.noteTarget.classList.remove("hidden")
    this.element.dataset.seatMapState = "failed"
  }

  retry() {
    this.failed = false
    this.noteTarget.classList.add("hidden")
    this.start()
  }

  resetView() {
    this.viewer?.home()
  }

  chooseGame() {
    this.formTarget.requestSubmit()
  }

  // A listing in the list: highlight it and its seats, and bring the 3D view round to them. Again lets go.
  pickItem(event) {
    const id = event.currentTarget.dataset.listingId
    this.select(this.selected.length === 1 && this.selected[0] === id ? [] : [ id ], { from: "list" })
  }

  select(ids, { from }) {
    this.selected = ids.map(String)
    const chosen = new Set(this.selected)
    let first = null
    for (const item of this.itemTargets) {
      const on = chosen.has(item.dataset.listingId)
      item.setAttribute("aria-pressed", String(on))
      if (on && !first) first = item
    }
    if (from === "list") this.viewer?.select(this.selected, { focus: true })
    if (from === "map" && first) this.scrollListTo(first)
    this.statusTarget.textContent = first
      ? `${this.selected.length > 1 ? `${this.selected.length} listings: ` : ""}${first.textContent.replace(/\s+/g, " ").trim()}`
      : ""
    this.element.dataset.seatMapSelected = this.selected.join(",")
  }

  // Inside the list's own scroll box, so neither the page nor the 3D view moves.
  scrollListTo(item) {
    const box = this.listTarget
    const top = item.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop
    const bottom = top + item.offsetHeight
    let to = null
    if (top < box.scrollTop) to = top - 8
    else if (bottom > box.scrollTop + box.clientHeight) to = bottom - box.clientHeight + 8
    if (to != null) box.scrollTo({ top: to, behavior: this.reducedMotion.matches ? "auto" : "smooth" })
  }

  // A game picked from the board below: bring the map into view.
  frameLoaded() {
    if (this.element.getBoundingClientRect().top < 0) {
      this.element.scrollIntoView({ behavior: this.reducedMotion.matches ? "auto" : "smooth", block: "start" })
    }
  }

  repaint() {
    this.paintSwatches()
    this.viewer?.setColors(this.colors())
  }

  // Each listing's swatch in the list takes its price color, as its seats do in 3D.
  paintSwatches() {
    if (!this.gameData) return
    const colors = this.colors()
    const [ low, high ] = this.gameData.range || [ 0, 1 ]
    for (const item of this.itemTargets) {
      const swatch = item.querySelector("[data-seat-map-swatch]")
      if (!swatch || item.dataset.role === "set_aside") continue
      const bucket = Math.min(4, Math.max(0, Math.floor(((Number(item.dataset.price) - low) / Math.max(high - low, 1)) * 5)))
      swatch.style.backgroundColor = colors.price[bucket]
    }
  }

  // The theme's colors for the 3D view: the seat map tokens plus a few for the court, light or dark.
  colors() {
    const style = getComputedStyle(document.documentElement)
    const token = (name) => style.getPropertyValue(`--color-${name}`).trim()
    const light = luminance(token("surface")) > 0.5
    return {
      light,
      seat: token("seat"),
      ours: token("seat-ours"),
      price: [ 1, 2, 3, 4, 5 ].map((i) => token(`price-${i}`)),
      label: token("content-strong"),
      labelDim: token("content-dim"),
      selection: light ? token("content-strong") : "#ffffff",
      tag: token("content-strong"),
      tagText: token("surface"),
      court: light ? "#d9b88f" : "#6e5843",
      lane: light ? "#6b93cc" : "#26476f",
      floor: light ? "#d7dbe6" : "#20222e",
      courtLine: light ? "#ffffff" : "#d6d1c4",
      steel: light ? "#8d93a8" : "#565d78"
    }
  }

  hook() {
    const controller = this
    return {
      controller,
      get ready() { return controller.element.dataset.seatMapState === "ready" },
      get selected() { return [ ...controller.selected ] },
      viewerSelected: () => [ ...(controller.viewer?.selected || []) ],
      screenPoint: (id) => controller.viewer?.screenPoint(id) ?? null
    }
  }
}

function luminance(hex) {
  const match = /^#?([0-9a-f]{6})$/i.exec(hex || "")
  if (!match) return 0
  const n = parseInt(match[1], 16)
  return (0.2126 * ((n >> 16) & 255) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)) / 255
}
