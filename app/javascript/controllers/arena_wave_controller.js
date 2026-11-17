import { Controller } from "@hotwired/stimulus"

// The sign-in page's backdrop: an arena bowl seen from courtside, rows of seats
// rising into the dark while the crowd does the wave, phones flashing in the
// stands, and our three seats in row DD lit orange.
//
// Canvas 2D. The seats are drawn once into an offscreen layer (on resize or a
// theme change); each frame copies that layer and adds only the wave, the
// flashes and our seats, a few hundred small circles. It stops while the tab is
// hidden and draws one still frame for people who prefer reduced motion. The
// element is data-turbo-permanent, so a failed sign-in, which re-renders the
// page, doesn't restart it.

const ROWS = 30
const DEPTH = 0.11                     // how quickly rows recede
const OURS_ROW = 3                     // row DD: AA, BB, CC, DD from the front
const WAVE = { speed: 15, sigma: 2.4, lag: 0.5, rest: 2.5 } // seats/s, seats, seats per row, s
const TAU = Math.PI * 2

export default class extends Controller {
  static targets = [ "canvas" ]

  connect() {
    this.time ??= 7.5
    this.flashes ??= []
    this.pen = this.canvasTarget.getContext("2d")
    this.base = document.createElement("canvas")
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    this.scheme = matchMedia("(prefers-color-scheme: dark)")

    this.relayout = () => { this.layout(); this.frame() }
    this.toggle = () => (document.hidden || this.motion.matches ? this.stop() : this.start())
    this.resizer = new ResizeObserver(this.relayout)
    this.resizer.observe(this.element)
    window.addEventListener("theme:change", this.relayout)
    this.scheme.addEventListener("change", this.relayout)
    this.motion.addEventListener("change", this.toggle)
    document.addEventListener("visibilitychange", this.toggle)

    this.layout()
    this.frame()
    this.toggle()
  }

  disconnect() {
    this.stop()
    this.resizer.disconnect()
    window.removeEventListener("theme:change", this.relayout)
    this.scheme.removeEventListener("change", this.relayout)
    this.motion.removeEventListener("change", this.toggle)
    document.removeEventListener("visibilitychange", this.toggle)
  }

  start() {
    if (this.running) return
    this.running = true
    let last = performance.now()
    const tick = (now) => {
      if (!this.running) return
      this.time += Math.min(now - last, 60) / 1000
      last = now
      this.frame()
      this.raf = requestAnimationFrame(tick)
    }
    this.raf = requestAnimationFrame(tick)
  }

  stop() {
    this.running = false
    cancelAnimationFrame(this.raf)
  }

  // Seat positions for this size. Rows recede toward a horizon high on the
  // screen, get longer as they go back, and rise at the ends like a bowl.
  layout() {
    const { width: w, height: h } = this.element.getBoundingClientRect()
    if (!w || !h) return
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    for (const canvas of [ this.canvasTarget, this.base ]) {
      canvas.width = Math.round(w * dpr)
      canvas.height = Math.round(h * dpr)
    }
    this.readColors()

    const pitch = Math.min(Math.max(w * 0.03, 26), 44) // px between front-row seats
    const horizon = h * 0.1
    const drop = h * 0.99 - horizon
    const bow = h * 0.24
    this.rows = []
    for (let i = 0; i < ROWS; i++) {
      const z = 1 + i * DEPTH
      const spacing = pitch / z
      const radius = Math.max(0.7, spacing * 0.27)
      const reach = Math.ceil((w / 2) / spacing) + 2
      const seats = []
      for (let k = -reach; k <= reach; k++) {
        const along = k + (i % 2 ? 0.5 : 0)
        const x = w / 2 + along * spacing
        const u = (x - w / 2) / (w / 2)
        const y = horizon + (drop - bow * u * u) / z
        if (x < -radius || x > w + radius || y > h + radius) continue
        seats.push({ along, x, y })
      }
      this.rows.push({ i, z, spacing, radius, fog: 1 - 0.72 * (i / (ROWS - 1)), seats })
    }
    this.span = Math.ceil((w / 2) / (pitch / (1 + (ROWS - 1) * DEPTH))) + ROWS * WAVE.lag + 10
    // Our three seats sit where they can be seen: beside the card on a wide
    // screen, under it on a narrow one.
    const dd = this.rows[OURS_ROW].seats
    const aim = w >= 900 ? w * 0.79 : w / 2
    const first = dd.reduce((best, seat, i) => (Math.abs(seat.x - aim) < Math.abs(dd[best].x - aim) ? i : best), 0)
    this.ours = dd.slice(Math.max(0, Math.min(first - 1, dd.length - 3)), Math.max(0, Math.min(first - 1, dd.length - 3)) + 3)
    Object.assign(this, { w, h, dpr })
    this.paintSeats()
  }

  readColors() {
    const css = getComputedStyle(this.element)
    const color = (name) => rgb(css.getPropertyValue(name))
    const canvas = color("--color-canvas")
    this.dark = luminance(canvas) < 0.3
    this.colors = {
      seat: color("--color-seat"),
      wave: color("--color-accent"),
      crest: this.dark ? mix(color("--color-accent"), [ 255, 255, 255 ], 0.45) : color("--color-accent"),
      ours: color("--color-brand-orange")
    }
  }

  // The empty arena, drawn once per size and theme.
  paintSeats() {
    const g = this.base.getContext("2d")
    g.setTransform(this.dpr, 0, 0, this.dpr, 0, 0)
    g.clearRect(0, 0, this.w, this.h)
    for (const row of this.rows) {
      g.fillStyle = rgba(this.colors.seat, (this.dark ? 0.95 : 0.9) * row.fog)
      g.beginPath()
      for (const seat of row.seats) {
        g.moveTo(seat.x + row.radius, seat.y)
        g.arc(seat.x, seat.y, row.radius, 0, TAU)
      }
      g.fill()
    }
  }

  // Where the crest is, in seats from the centre of the front row. It sweeps
  // the bowl left to right, rests, and goes again.
  crest() {
    const travel = this.span * 2
    const period = travel / WAVE.speed + WAVE.rest
    return -this.span + Math.min((this.time % period) * WAVE.speed, travel)
  }

  frame() {
    if (!this.rows) return
    const c = this.pen
    c.setTransform(this.dpr, 0, 0, this.dpr, 0, 0)
    c.clearRect(0, 0, this.w, this.h)
    c.drawImage(this.base, 0, 0, this.w, this.h)
    c.globalCompositeOperation = this.dark ? "lighter" : "source-over"

    const crest = this.crest()
    const width = WAVE.sigma * 3
    for (const row of this.rows) {
      const centre = crest - row.i * WAVE.lag
      for (const seat of row.seats) {
        const d = seat.along - centre
        if (d < -width || d > width) continue
        const lift = Math.exp(-(d * d) / (2 * WAVE.sigma * WAVE.sigma))
        this.fan(c, seat.x, seat.y - lift * row.spacing * 0.9, row, lift)
      }
    }

    if (this.dark && !this.motion.matches) this.cameraFlashes(c)
    this.ourSeats(c, crest)
    c.globalCompositeOperation = "source-over"
  }

  // A fan on their feet: a soft halo and a bright head.
  fan(c, x, y, row, lift) {
    c.fillStyle = rgba(this.colors.wave, (this.dark ? 0.2 : 0.12) * lift * row.fog)
    circle(c, x, y, row.radius * 2.6)
    c.fillStyle = rgba(this.colors.crest, (0.2 + 0.8 * lift) * row.fog)
    circle(c, x, y, row.radius * (0.85 + 0.35 * lift))
  }

  // Phones going off in the stands: a quick white pop with a small glint.
  cameraFlashes(c) {
    const now = this.time
    if (Math.random() < 0.045) {
      const row = this.rows[4 + Math.floor(Math.random() * (ROWS - 4))]
      const seat = row?.seats[Math.floor(Math.random() * row.seats.length)]
      if (seat) this.flashes.push({ x: seat.x, y: seat.y - row.spacing * 0.5, r: row.radius, born: now })
    }
    this.flashes = this.flashes.filter((f) => now - f.born < 0.45 && now >= f.born)
    for (const f of this.flashes) {
      const a = (1 - (now - f.born) / 0.45) ** 2
      c.fillStyle = `rgba(255,255,255,${0.9 * a})`
      circle(c, f.x, f.y, f.r * 1.3)
      c.strokeStyle = `rgba(255,255,255,${0.35 * a})`
      c.lineWidth = Math.max(0.6, f.r * 0.35)
      c.beginPath()
      c.moveTo(f.x - f.r * 4, f.y); c.lineTo(f.x + f.r * 4, f.y)
      c.moveTo(f.x, f.y - f.r * 4); c.lineTo(f.x, f.y + f.r * 4)
      c.stroke()
    }
  }

  // Section 101, row DD, seats 1-3: always lit, and up with the wave.
  ourSeats(c, crest) {
    const row = this.rows[OURS_ROW]
    if (!row || !this.ours) return
    const pulse = 0.78 + 0.22 * Math.sin(this.time * 2.2)
    const centre = crest - row.i * WAVE.lag
    c.globalCompositeOperation = "source-over" // added light would wash the orange out to white
    for (const seat of this.ours) {
      const d = seat.along - centre
      const lift = Math.exp(-(d * d) / (2 * WAVE.sigma * WAVE.sigma))
      const y = seat.y - lift * row.spacing * 0.9
      c.fillStyle = rgba(this.colors.ours, 0.2 * pulse + 0.15 * lift)
      circle(c, seat.x, y, row.radius * 2.8)
      c.fillStyle = rgba(this.colors.ours, 1)
      circle(c, seat.x, y, row.radius * (1 + 0.25 * lift))
    }
  }
}

function circle(c, x, y, r) {
  c.beginPath()
  c.arc(x, y, r, 0, TAU)
  c.fill()
}

function rgb(value) {
  const hex = value.trim().replace("#", "")
  const full = hex.length === 3 ? hex.split("").map((ch) => ch + ch).join("") : hex
  const n = parseInt(full || "000000", 16)
  return [ (n >> 16) & 255, (n >> 8) & 255, n & 255 ]
}

function rgba([ r, g, b ], a) {
  return `rgba(${r},${g},${b},${Math.max(0, Math.min(1, a)).toFixed(3)})`
}

function mix(a, b, t) {
  return a.map((v, i) => Math.round(v + (b[i] - v) * t))
}

function luminance([ r, g, b ]) {
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
}
