import {
  AdditiveBlending, BoxGeometry, BufferGeometry, CanvasTexture, Color, DirectionalLight, Float32BufferAttribute,
  HemisphereLight, InstancedMesh, LineBasicMaterial, LineSegments, MathUtils, Mesh, MeshBasicMaterial,
  MeshStandardMaterial, NormalBlending, Object3D, PerspectiveCamera, PlaneGeometry, Raycaster, Scene, Sprite, SpriteMaterial,
  TorusGeometry, Vector2, Vector3, WebGLRenderer
} from "three"
import { OrbitControls } from "three/addons/controls/OrbitControls"
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry"
import { planArena } from "arena3d/layout"

// The seat map in 3D (seat_map_controller.js makes one): the home-end sections from the venue file, every listing of
// one game on its seats (or, when the research only knows its row, a strip over that row), colored by price.
// Rendered only when something changes or moves, never in a constant loop. Drag to turn, pinch or scroll to zoom; a
// tap picks a listing and tells the controller, which highlights it in the list (and the list does the same back).
//
// Debug hooks: window.__seatMapCount is how many viewers (each one renderer and one WebGL context) are alive.

const FOV = 38
const TAP_SLOP = 8 // px a finger may wander and still tap
const VIEW_FROM = new Vector3(0, 0.92, -1).normalize() // from the court, looking up into the stands
const MAX_GLOW = 96

const count = (delta) => { window.__seatMapCount = (window.__seatMapCount || 0) + delta }

export function createViewer(stage, options) {
  return new ArenaViewer(stage, options)
}

class ArenaViewer {
  constructor(stage, { venue, colors, reducedMotion = false, onSelect, onLost }) {
    this.stage = stage
    this.venue = venue
    this.colors = colors
    this.reducedMotion = reducedMotion
    this.callbacks = { onSelect, onLost }
    this.selected = []
    this.disposables = new Set()
    this.focus = null

    this.canvas = document.createElement("canvas")
    this.canvas.setAttribute("aria-hidden", "true")
    Object.assign(this.canvas.style, { display: "block", width: "100%", height: "100%", touchAction: "none", userSelect: "none" })
    stage.append(this.canvas)
    // Throws without WebGL 2; the controller then keeps to the list.
    this.renderer = new WebGLRenderer({ canvas: this.canvas, antialias: true, alpha: true, powerPreference: "low-power" })
    count(1)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))

    this.scene = new Scene()
    this.camera = new PerspectiveCamera(FOV, 1, 1, 2500)
    this.scene.add(new HemisphereLight(0xffffff, 0x50536a, 2.1))
    const sun = new DirectionalLight(0xffffff, 1.5)
    sun.position.set(-40, 140, -90)
    this.scene.add(sun)

    this.controls = new OrbitControls(this.camera, this.canvas)
    Object.assign(this.controls, {
      enableDamping: !reducedMotion, dampingFactor: 0.12, screenSpacePanning: true,
      minDistance: 14, maxDistance: 480, maxPolarAngle: MathUtils.degToRad(86), zoomToCursor: true
    })
    this.onControlsChange = () => this.requestRender()
    this.onControlsStart = () => { this.focus = null; this.interacted = true }
    this.controls.addEventListener("change", this.onControlsChange)
    this.controls.addEventListener("start", this.onControlsStart)

    this.raycaster = new Raycaster()
    this.buildCourt()

    this.onContextLost = (event) => {
      event.preventDefault()
      this.callbacks.onLost?.()
    }
    this.canvas.addEventListener("webglcontextlost", this.onContextLost)
    this.bindTap()
    this.resizeObserver = new ResizeObserver(() => this.resize())
    this.resizeObserver.observe(stage)
    this.resize()
  }

  keep(thing) {
    this.disposables.add(thing)
    return thing
  }

  // One game's listings. The seats are rebuilt only when a listing names a seat past a row's modeled end.
  setData(data) {
    this.data = data
    const needs = new Map()
    for (const listing of data.listings) {
      for (const seat of listing.seats || []) {
        const key = `${listing.section}|${listing.row}`
        needs.set(key, Math.max(needs.get(key) || 0, seat))
      }
    }
    const signature = JSON.stringify([ ...needs ].sort())
    if (!this.plan || signature !== this.planSignature) {
      this.plan = planArena(this.venue, needs)
      this.planSignature = signature
      this.buildSeats()
      this.buildLabels()
      if (!this.interacted) this.home({ jump: true })
    }
    this.mapListings()
    this.paint()
    this.select([], { silent: true })
  }

  setColors(colors) {
    this.colors = colors
    this.paintCourt()
    if (this.plan) {
      this.buildLabels()
      this.paint()
      this.select(this.selected)
    }
    this.requestRender()
  }

  // ids: listing ids to highlight. focus: ease the camera over to them (a pick from the list).
  select(ids, { focus = false } = {}) {
    this.selected = ids.map(String).filter((id) => this.listings?.has(id))
    this.glowStart = performance.now()
    this.updateGlow()
    this.updateTag()
    if (focus && this.selected.length) this.focusOn(this.anchorFor(this.selected))
    this.requestRender()
  }

  // Where a listing shows on screen, in client coordinates (for the system tests' taps): the top of its first seat,
  // since the middle of a pair falls in the gap between two cushions.
  screenPoint(id) {
    const anchor = this.anchorFor([ String(id) ], { surface: true, first: true })
    if (!anchor) return null
    const v = anchor.clone().project(this.camera)
    const rect = this.canvas.getBoundingClientRect()
    return { x: rect.left + ((v.x + 1) / 2) * rect.width, y: rect.top + ((1 - v.y) / 2) * rect.height }
  }

  // The whole of the stands from the court: the camera backs off along VIEW_FROM until every corner of their box
  // lands inside the view, with a margin (a few rounds, since perspective doesn't scale evenly).
  home({ jump = false } = {}) {
    if (!this.plan || !this.size) return
    const { min, max } = this.plan.bounds
    const center = new Vector3((min.x + max.x) / 2, (min.y + max.y) * 0.35, (min.z + max.z) * 0.48)
    const corners = []
    for (const x of [ min.x, max.x ]) for (const y of [ min.y, max.y ]) for (const z of [ min.z, max.z ]) corners.push(new Vector3(x, y, z))
    const probe = this.camera.clone()
    let distance = 220
    for (let round = 0; round < 5; round++) {
      probe.position.copy(center).addScaledVector(VIEW_FROM, distance)
      probe.lookAt(center)
      probe.updateMatrixWorld()
      const spread = Math.max(...corners.map((c) => {
        const p = c.clone().project(probe)
        return Math.max(Math.abs(p.x), Math.abs(p.y))
      }))
      distance *= spread / 0.94
    }
    const position = center.clone().addScaledVector(VIEW_FROM, distance)
    if (jump || this.reducedMotion) {
      this.focus = null
      this.controls.target.copy(center)
      this.camera.position.copy(position)
      this.controls.update()
    } else {
      this.focus = { target: center, position }
    }
    this.interacted = false
    this.requestRender()
  }

  requestRender() {
    if (this.frameRequested || this.disposed) return
    this.frameRequested = true
    this.raf = requestAnimationFrame((time) => this.frame(time))
  }

  frame(time) {
    this.frameRequested = false
    if (this.disposed || !this.size) return
    const dt = this.lastTime ? Math.min((time - this.lastTime) / 1000, 1 / 20) : 1 / 60
    this.lastTime = time
    let moving = this.stepFocus(dt)
    moving = this.controls.update(dt) || moving
    moving = this.stepGlow(time) || moving
    this.renderer.render(this.scene, this.camera)
    if (moving) this.requestRender()
    else this.lastTime = 0
  }

  resize() {
    const width = this.stage.clientWidth
    const height = this.stage.clientHeight
    if (!width || !height) return
    this.size = { width, height }
    this.renderer.setSize(width, height, false)
    this.camera.aspect = width / height
    this.camera.updateProjectionMatrix()
    if (!this.interacted) this.home({ jump: true })
    this.requestRender()
  }

  // The court end for bearings: the floor, its lines, and the basket on its stanchion.
  buildCourt() {
    const court = new Mesh(this.keep(new PlaneGeometry(50, 47)), this.keep(new MeshStandardMaterial({ roughness: 0.6 })))
    court.rotation.x = -Math.PI / 2
    court.position.set(0, 0, -23.5)
    const apron = new Mesh(this.keep(new PlaneGeometry(64, 16)), this.keep(new MeshStandardMaterial({ roughness: 0.9 })))
    apron.rotation.x = -Math.PI / 2
    apron.position.set(0, -0.02, 8)
    const lane = new Mesh(this.keep(new PlaneGeometry(16, 19)), this.keep(new MeshStandardMaterial({ roughness: 0.6 })))
    lane.rotation.x = -Math.PI / 2
    lane.position.set(0, 0.01, -9.5)
    this.court = { court, apron, lane }

    const points = []
    const segment = (ax, az, bx, bz) => points.push(ax, 0.03, az, bx, 0.03, bz)
    const arc = (cx, cz, r, from, to, steps = 32) => {
      for (let i = 0; i < steps; i++) {
        const a = from + ((to - from) * i) / steps
        const b = from + ((to - from) * (i + 1)) / steps
        segment(cx + r * Math.sin(a), cz - r * Math.cos(a), cx + r * Math.sin(b), cz - r * Math.cos(b))
      }
    }
    segment(-25, 0, 25, 0) // baseline
    segment(-25, 0, -25, -47)
    segment(25, 0, 25, -47)
    segment(-25, -47, 25, -47) // half-court line
    segment(-8, 0, -8, -19) // the lane
    segment(8, 0, 8, -19)
    segment(-8, -19, 8, -19)
    arc(0, -19, 6, -Math.PI / 2, Math.PI / 2) // free-throw circle, court side
    segment(-22, 0, -22, -14) // three-point corners and arc
    segment(22, 0, 22, -14)
    const corner = Math.asin(22 / 23.75)
    arc(0, -5.25, 23.75, -corner, corner, 48)
    arc(0, -5.25, 4, -Math.PI / 2, Math.PI / 2, 16) // restricted area
    arc(0, -47, 6, -Math.PI / 2, Math.PI / 2) // center circle
    const lines = new BufferGeometry()
    lines.setAttribute("position", new Float32BufferAttribute(points, 3))
    this.courtLines = new LineSegments(this.keep(lines), this.keep(new LineBasicMaterial()))

    const steel = this.keep(new MeshStandardMaterial({ roughness: 0.5, metalness: 0.2 }))
    const glass = this.keep(new MeshStandardMaterial({ roughness: 0.1, transparent: true, opacity: 0.35 }))
    const board = new Mesh(this.keep(new BoxGeometry(6, 3.5, 0.15)), glass)
    board.position.set(0, 11.5, -4)
    const rim = new Mesh(this.keep(new TorusGeometry(0.75, 0.07, 8, 24)), this.keep(new MeshStandardMaterial({ color: 0xe8642c })))
    rim.rotation.x = Math.PI / 2
    rim.position.set(0, 10, -5.25)
    const arm = new Mesh(this.keep(new BoxGeometry(0.6, 0.6, 7)), steel)
    arm.position.set(0, 12.5, -0.6)
    const post = new Mesh(this.keep(new BoxGeometry(1.4, 12.5, 1.4)), steel)
    post.position.set(0, 6.25, 2.6)
    const base = new Mesh(this.keep(new BoxGeometry(5, 2, 5.5)), steel)
    base.position.set(0, 1, 3.5)
    this.steel = steel
    this.scene.add(court, apron, lane, this.courtLines, board, rim, arm, post, base)
    this.paintCourt()
  }

  paintCourt() {
    const c = this.colors
    this.court.court.material.color.set(c.court)
    this.court.lane.material.color.set(c.lane)
    this.court.apron.material.color.set(c.floor)
    this.courtLines.material.color.set(c.courtLine)
    this.steel.color.set(c.steel)
  }

  // Every seat as one chair (cushion and back), drawn in two instanced meshes; a seat's index is its place in the plan.
  buildSeats() {
    for (const mesh of [ this.cushions, this.backs, this.glow ]) {
      if (!mesh) continue
      this.scene.remove(mesh)
      mesh.dispose()
    }
    const seats = this.plan.seats
    if (!this.chair) {
      const cushion = new RoundedBoxGeometry(1.45, 0.42, 1.35, 2, 0.12)
      cushion.translate(0, 0.45, 0)
      const back = new RoundedBoxGeometry(1.45, 1.35, 0.28, 2, 0.1)
      back.translate(0, 1.1, 0.62)
      this.chair = { cushion: this.keep(cushion), back: this.keep(back) }
      this.chairMaterial = this.keep(new MeshStandardMaterial({ roughness: 0.8 }))
      this.glowMaterial = this.keep(new MeshBasicMaterial({ transparent: true, opacity: 0.4, depthWrite: false, blending: AdditiveBlending }))
      this.glowGeometry = this.keep(new BoxGeometry(1, 1, 1))
    }
    this.cushions = new InstancedMesh(this.chair.cushion, this.chairMaterial, seats.length)
    this.backs = new InstancedMesh(this.chair.back, this.chairMaterial, seats.length)
    const place = new Object3D()
    seats.forEach((seat, i) => {
      place.position.set(seat.x, seat.y, seat.z)
      place.rotation.set(0, seat.yaw, 0)
      place.updateMatrix()
      this.cushions.setMatrixAt(i, place.matrix)
      this.backs.setMatrixAt(i, place.matrix)
    })
    this.glow = new InstancedMesh(this.glowGeometry, this.glowMaterial, MAX_GLOW)
    this.glow.count = 0
    this.glow.renderOrder = 2
    this.glow.frustumCulled = false
    this.scene.add(this.cushions, this.backs, this.glow)
  }

  // Which listings sit on which seats, and the rows where only the row is known (one strip over each).
  mapListings() {
    this.listings = new Map()
    this.seatListings = new Map()
    this.rowOnly = new Map()
    for (const listing of this.data.listings) {
      const id = String(listing.id)
      this.listings.set(id, listing)
      const rowKey = `${listing.section}|${listing.row}`
      if (!this.plan.rows.has(rowKey)) continue
      if (listing.seats?.length) {
        for (const seat of listing.seats) {
          const index = this.plan.index.get(`${rowKey}|${seat}`)
          if (index != null) push(this.seatListings, index, id)
        }
      } else {
        push(this.rowOnly, rowKey, id)
      }
    }
    const ours = this.data.ours
    this.ourSeats = new Set((ours?.seats || []).map((s) => this.plan.index.get(`${ours.section}|${ours.row}|${s}`)).filter((i) => i != null))

    if (this.strips) {
      this.scene.remove(this.strips)
      this.strips.dispose()
    }
    this.stripKeys = [ ...this.rowOnly.keys() ]
    this.stripGeometry ||= this.keep(new BoxGeometry(1, 0.32, 0.32))
    this.stripMaterial ||= this.keep(new MeshStandardMaterial({ roughness: 0.4, transparent: true, opacity: 0.88 }))
    this.strips = new InstancedMesh(this.stripGeometry, this.stripMaterial, Math.max(this.stripKeys.length, 1))
    this.strips.count = this.stripKeys.length
    const place = new Object3D()
    this.stripKeys.forEach((key, i) => {
      const row = this.plan.rows.get(key)
      place.position.set(row.mid.x, row.mid.y + 2.4, row.mid.z + 0.2)
      place.rotation.set(0, row.yaw, 0)
      place.scale.set(row.length, 1, 1)
      place.updateMatrix()
      this.strips.setMatrixAt(i, place.matrix)
    })
    this.scene.add(this.strips)
  }

  priceColor(price) {
    const [ low, high ] = this.data.range || [ price, price + 1 ]
    const bucket = MathUtils.clamp(Math.floor(((price - low) / Math.max(high - low, 1)) * 5), 0, 4)
    return this.colors.price[bucket]
  }

  paint() {
    const color = new Color()
    this.plan.seats.forEach((_, i) => {
      const ids = this.seatListings.get(i)
      if (this.ourSeats.has(i)) color.set(this.colors.ours)
      else if (ids) color.set(this.priceColor(Math.min(...ids.map((id) => this.listings.get(id).price))))
      else color.set(this.colors.seat)
      this.cushions.setColorAt(i, color)
      this.backs.setColorAt(i, color)
    })
    this.cushions.instanceColor.needsUpdate = true
    this.backs.instanceColor.needsUpdate = true
    this.stripKeys.forEach((key, i) => {
      color.set(this.priceColor(Math.min(...this.rowOnly.get(key).map((id) => this.listings.get(id).price))))
      this.strips.setColorAt(i, color)
    })
    if (this.strips.instanceColor) this.strips.instanceColor.needsUpdate = true
    // A light glow adds up on dark seats; on light ones it would vanish, so it darkens them instead.
    this.glowMaterial.color.set(this.colors.selection)
    this.glowMaterial.blending = this.colors.light ? NormalBlending : AdditiveBlending
    this.glowMaterial.needsUpdate = true
    this.requestRender()
  }

  // Section numbers over each section, and a few row letters along the center aisle.
  buildLabels() {
    for (const sprite of this.labels || []) {
      this.scene.remove(sprite)
      sprite.material.map.dispose()
      sprite.material.dispose()
    }
    this.labels = []
    for (const section of this.plan.sections) {
      const sprite = textSprite(section.estimated ? `${section.id}*` : section.id, { color: this.colors.label, size: 64, weight: 700, height: 5.5 })
      sprite.position.set(section.label.x, section.label.y, section.label.z)
      this.labels.push(sprite)
    }
    for (const row of this.plan.rowLabels) {
      const sprite = textSprite(row.text, { color: this.colors.labelDim, size: 40, weight: 600, height: 2.3 })
      sprite.position.set(row.x, row.y, row.z)
      this.labels.push(sprite)
    }
    this.scene.add(...this.labels)
  }

  // A glowing box around each selected seat, or along its row when only the row is known.
  updateGlow() {
    if (!this.glow) return
    const place = new Object3D()
    let n = 0
    for (const id of this.selected) {
      const listing = this.listings.get(id)
      const rowKey = `${listing.section}|${listing.row}`
      const seats = (listing.seats || []).map((s) => this.plan.index.get(`${rowKey}|${s}`)).filter((i) => i != null)
      if (seats.length) {
        for (const index of seats) {
          if (n >= MAX_GLOW) break
          const seat = this.plan.seats[index]
          place.position.set(seat.x, seat.y + 0.9, seat.z + 0.15)
          place.rotation.set(0, seat.yaw, 0)
          place.scale.set(1.95, 2.1, 1.95)
          place.updateMatrix()
          this.glow.setMatrixAt(n++, place.matrix)
        }
      } else if (this.plan.rows.has(rowKey) && n < MAX_GLOW) {
        const row = this.plan.rows.get(rowKey)
        place.position.set(row.mid.x, row.mid.y + 2.4, row.mid.z + 0.2)
        place.rotation.set(0, row.yaw, 0)
        place.scale.set(row.length + 0.8, 1.1, 1.1)
        place.updateMatrix()
        this.glow.setMatrixAt(n++, place.matrix)
      }
    }
    this.glow.count = n
    this.glow.instanceMatrix.needsUpdate = true
  }

  stepGlow(time) {
    if (!this.glow?.count) return false
    if (this.reducedMotion) {
      this.glowMaterial.opacity = 0.45
      return false
    }
    const t = (time - this.glowStart) / 1000
    const pulsing = t < 2.4
    this.glowMaterial.opacity = pulsing ? 0.3 + 0.25 * (0.5 + 0.5 * Math.sin(t * Math.PI * 2.5)) : 0.42
    return pulsing
  }

  // The price tag over the selection.
  updateTag() {
    if (this.tag) {
      this.scene.remove(this.tag)
      this.tag.material.map.dispose()
      this.tag.material.dispose()
      this.tag = null
    }
    const anchor = this.selected.length && this.anchorFor(this.selected)
    if (!anchor) return
    const listings = this.selected.map((id) => this.listings.get(id))
    const prices = listings.map((l) => l.price).sort((a, b) => a - b)
    const money = (p) => `$${p.toFixed(2)}`
    const first = listings[0]
    const where = `${first.section} · ${first.row}`
    const text = listings.length === 1 ? `${money(prices[0])} · ${where}` : `${listings.length} listings · ${money(prices[0])}–${money(prices.at(-1))}`
    // The same size on screen however far out the view is.
    this.tag = textSprite(text, { color: this.colors.tagText, background: this.colors.tag, size: 44, weight: 700, height: 0.055, fixed: true })
    this.tag.position.set(anchor.x, anchor.y + 5, anchor.z)
    this.tag.renderOrder = 3
    this.tag.material.depthTest = false
    this.scene.add(this.tag)
  }

  // The middle of a selection: its seats, or its row's strip.
  anchorFor(ids, { surface = false, first = false } = {}) {
    const points = []
    for (const id of ids) {
      const listing = this.listings?.get(id)
      if (!listing) continue
      const rowKey = `${listing.section}|${listing.row}`
      const seats = (listing.seats || []).map((s) => this.plan.index.get(`${rowKey}|${s}`)).filter((i) => i != null)
      if (seats.length) {
        for (const index of seats) {
          const seat = this.plan.seats[index]
          points.push(new Vector3(seat.x, seat.y + (surface ? 0.66 : 1), seat.z))
        }
      } else if (this.plan.rows.has(rowKey)) {
        const row = this.plan.rows.get(rowKey)
        points.push(new Vector3(row.mid.x, row.mid.y + 2.4, row.mid.z + 0.2))
      }
    }
    if (!points.length) return null
    if (first) return points[0]
    return points.reduce((sum, p) => sum.add(p), new Vector3()).divideScalar(points.length)
  }

  focusOn(anchor) {
    if (!anchor) return
    const offset = this.camera.position.clone().sub(this.controls.target)
    const distance = Math.min(offset.length(), 95)
    const position = anchor.clone().add(offset.setLength(distance))
    if (this.reducedMotion) {
      this.controls.target.copy(anchor)
      this.camera.position.copy(position)
      this.controls.update()
    } else {
      this.focus = { target: anchor.clone(), position }
    }
  }

  stepFocus(dt) {
    if (!this.focus) return false
    const k = 1 - Math.exp(-dt * 6)
    this.controls.target.lerp(this.focus.target, k)
    this.camera.position.lerp(this.focus.position, k)
    if (this.controls.target.distanceTo(this.focus.target) < 0.05 && this.camera.position.distanceTo(this.focus.position) < 0.05) {
      this.focus = null
    }
    return true
  }

  // A tap (not a drag) picks what's under it: a listed seat, a row strip, or a seat in a row with a row-only listing.
  bindTap() {
    let down = null
    this.onPointerDown = (event) => {
      if (event.isPrimary) down = { x: event.clientX, y: event.clientY, at: performance.now() }
    }
    this.onPointerUp = (event) => {
      if (!down || !event.isPrimary) return
      const moved = Math.hypot(event.clientX - down.x, event.clientY - down.y)
      const quick = performance.now() - down.at < 650
      down = null
      if (moved < TAP_SLOP && quick && event.type === "pointerup") this.tap(event.clientX, event.clientY)
    }
    this.canvas.addEventListener("pointerdown", this.onPointerDown)
    this.canvas.addEventListener("pointerup", this.onPointerUp)
    this.canvas.addEventListener("pointercancel", this.onPointerUp)
  }

  tap(clientX, clientY) {
    const ids = this.pick(clientX, clientY)
    this.select(ids)
    this.callbacks.onSelect?.(ids)
  }

  pick(clientX, clientY) {
    if (!this.plan) return []
    const rect = this.canvas.getBoundingClientRect()
    const pointer = new Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1)
    this.raycaster.setFromCamera(pointer, this.camera)
    const hits = this.raycaster.intersectObjects([ this.strips, this.cushions, this.backs ].filter(Boolean), false)
    for (const hit of hits) {
      if (hit.object === this.strips) return [ ...(this.rowOnly.get(this.stripKeys[hit.instanceId]) || []) ]
      const listed = this.seatListings.get(hit.instanceId)
      if (listed) return [ ...listed ]
      const seat = this.plan.seats[hit.instanceId]
      return [ ...(this.rowOnly.get(`${seat.section}|${seat.row}`) || []) ]
    }
    return []
  }

  // Everything this viewer made goes: meshes, materials, textures, the renderer and its context.
  dispose() {
    if (this.disposed) return
    this.disposed = true
    cancelAnimationFrame(this.raf)
    this.resizeObserver.disconnect()
    this.canvas.removeEventListener("webglcontextlost", this.onContextLost)
    this.canvas.removeEventListener("pointerdown", this.onPointerDown)
    this.canvas.removeEventListener("pointerup", this.onPointerUp)
    this.canvas.removeEventListener("pointercancel", this.onPointerUp)
    this.controls.removeEventListener("change", this.onControlsChange)
    this.controls.removeEventListener("start", this.onControlsStart)
    this.controls.dispose()
    for (const sprite of [ ...(this.labels || []), this.tag ].filter(Boolean)) {
      sprite.material.map.dispose()
      sprite.material.dispose()
    }
    for (const mesh of [ this.cushions, this.backs, this.glow, this.strips ]) mesh?.dispose()
    for (const thing of this.disposables) thing.dispose()
    this.renderer.renderLists.dispose()
    this.renderer.dispose()
    // Hands the context back to the browser now rather than at garbage collection (a lost one already is).
    if (!this.renderer.getContext().isContextLost()) this.renderer.forceContextLoss()
    this.canvas.remove()
    count(-1)
  }
}

function push(map, key, value) {
  const list = map.get(key)
  if (list) list.push(value)
  else map.set(key, [ value ])
}

// Text on a canvas, as a sprite that always faces the camera; height is in feet, or with fixed, a share of the view's
// height whatever the distance.
function textSprite(text, { color, background = null, size = 48, weight = 600, height = 2, fixed = false }) {
  const font = `${weight} ${size}px system-ui, -apple-system, "Segoe UI", sans-serif`
  const pad = background ? size * 0.45 : size * 0.12
  const measure = document.createElement("canvas").getContext("2d")
  measure.font = font
  const width = Math.ceil(measure.measureText(text).width + pad * 2)
  const tall = Math.ceil(size * 1.35 + pad * (background ? 1 : 0.5))
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = tall
  const ctx = canvas.getContext("2d")
  if (background) {
    ctx.fillStyle = background
    const r = tall / 2.4
    ctx.beginPath()
    ctx.roundRect(0, 0, width, tall, r)
    ctx.fill()
  } else {
    ctx.shadowColor = "rgba(0, 0, 0, 0.55)"
    ctx.shadowBlur = size * 0.18
  }
  ctx.font = font
  ctx.fillStyle = color
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  ctx.fillText(text, width / 2, tall / 2 + size * 0.04)
  const texture = new CanvasTexture(canvas)
  texture.anisotropy = 4
  const sprite = new Sprite(new SpriteMaterial({ map: texture, transparent: true, depthWrite: false, sizeAttenuation: !fixed }))
  sprite.scale.set((height * width) / tall, height, 1)
  return sprite
}
