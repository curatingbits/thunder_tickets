// Where every seat of the seat map sits: numbers only, no three.js. In feet, with the origin where the basket line meets
// the baseline at this end: z runs back from the court into the stands (the court is z < 0), y is up, and x runs along
// the baseline. The camera looks from the court toward +z, which puts +x on the left of the screen, so 119 and 120 (on
// the left, seen from the court) are +x and 101 and 102 are -x.
//
// 120 and 101 have straight rows parallel to the baseline, filling outward from the center aisle; their outer ends
// make the flared edge Ticketmaster's map shows. Each row then carries on into its corner section (119, 102) along a
// 45° diagonal, which gives the corner wedges. Seat numbers run left to right as seen from the court, so seat 1 of 101
// is on the aisle and seat 1 of 120 is at the 119 end (config/venues/paycom_center.yml).

const PITCH = 1.75 // seat width
const AISLE = 1.75 // half the center aisle (about two seats wide)
const ROW_DEPTH = 2.75
const SECTION_GAP = 0.9 // between a baseline section and its corner, along the row
const DIAGONAL = Math.SQRT1_2

// Row ranks follow Market::RowOrder: FL1-FL3 = 0-2, AA = 3 ... UU = 21, J = 22 ... U = 32.
export function rowDepth(rank) {
  if (rank <= 2) return 4 + rank * ROW_DEPTH // the floor rows, just behind the baseline
  // About two rows of open floor before AA; the step to UU is a little deeper.
  return 9.5 + 3 * ROW_DEPTH + (rank - 3) * ROW_DEPTH + (rank >= 21 ? 0.6 : 0)
}

export function rowHeight(rank) {
  if (rank <= 2) return 0.15 * rank // on the floor
  if (rank <= 21) return 1.5 + (rank - 3) * 1.0 // AA-UU: a shallow rake (retractable seating)
  return 19.5 + 1.5 + (rank - 22) * 1.6 // J-U: steeper
}

// needs: Map of "section|row" => the highest seat a listing names, so a row the file models too short still fits it.
export function planArena(venue, needs = new Map()) {
  const seats = []
  const index = new Map()
  const rows = new Map()
  const sections = []
  const rowLabels = []
  const ends = { left: new Map(), right: new Map() } // baseline row rank => how far out its last seat reaches

  const ordered = [ ...venue.sections ].sort((a, b) => (a.shape === "baseline" ? 0 : 1) - (b.shape === "baseline" ? 0 : 1))
  for (const section of ordered) {
    const right = section.side === "right"
    const side = right ? -1 : 1 // which way along x is outward from the center aisle
    const sectionSeats = []
    for (const [name, rank, modeled, offset] of section.rows) {
      const count = Math.max(modeled, needs.get(`${section.id}|${name}`) || 0)
      const depth = rowDepth(rank)
      const height = rowHeight(rank)
      let start
      let along
      let facing
      if (section.shape === "baseline") {
        const t0 = rank <= 2 ? 0 : AISLE
        start = { x: side * t0, z: depth }
        along = { x: side, z: 0 }
        facing = { x: 0, z: -1 }
        ends[section.side].set(rank, t0 + (offset + count) * PITCH)
      } else {
        const reach = baselineEnd(ends[section.side], rank) + SECTION_GAP
        start = { x: side * reach, z: depth }
        along = { x: side * DIAGONAL, z: -DIAGONAL }
        facing = { x: -side * DIAGONAL, z: -DIAGONAL }
      }
      const yaw = Math.atan2(-facing.x, -facing.z) // chairs are built facing -z
      const members = []
      for (let i = 0; i < count; i++) {
        const s = (offset + i + 0.5) * PITCH
        // Numbers rise left to right from the court: from the inner end on the right side, the outer end on the left.
        const seat = right ? i + 1 : count - i
        const at = { x: start.x + along.x * s, y: height, z: start.z + along.z * s }
        const key = `${section.id}|${name}|${seat}`
        index.set(key, seats.length)
        members.push(seats.length)
        seats.push({ key, section: section.id, row: name, seat, ...at, yaw })
      }
      const first = seats[members[0]]
      const last = seats[members.at(-1)]
      rows.set(`${section.id}|${name}`, {
        section: section.id, row: name, seats: members, yaw, length: count * PITCH,
        mid: { x: (first.x + last.x) / 2, y: height, z: (first.z + last.z) / 2 },
        along
      })
      sectionSeats.push(...members)
      // Row letters down the center aisle, once for both halves.
      if (section.shape === "baseline" && LABELED_ROWS.has(name) && !rowLabels.some((label) => label.text === name)) {
        rowLabels.push({ text: name, x: 0, y: height + 1.2, z: depth })
      }
    }
    const middle = section.rows[Math.floor(section.rows.length * 0.55)]
    const anchor = rows.get(`${section.id}|${middle[0]}`).mid
    sections.push({ id: section.id, estimated: section.estimated, label: { x: anchor.x, y: anchor.y + 9, z: anchor.z } })
  }

  const min = { x: Infinity, y: 0, z: 0 }
  const max = { x: -Infinity, y: -Infinity, z: -Infinity }
  for (const s of seats) {
    min.x = Math.min(min.x, s.x)
    max.x = Math.max(max.x, s.x)
    max.y = Math.max(max.y, s.y)
    max.z = Math.max(max.z, s.z)
  }
  return { seats, index, rows, sections, rowLabels, bounds: { min, max } }
}

const LABELED_ROWS = new Set([ "AA", "DD", "GG", "MM", "UU", "N", "U" ])

// A corner row starts where the baseline row of the same rank ends; 120 has no S or T (row SA stands for S), so a
// missing rank borrows its nearest neighbor's reach.
function baselineEnd(ends, rank) {
  for (let d = 0; d < 6; d++) {
    if (ends.has(rank - d)) return ends.get(rank - d)
    if (ends.has(rank + d)) return ends.get(rank + d)
  }
  return 12
}
