// Reads one Ticketmaster event page the way Kate did on 2026-11-16:
// accept the purchase-policy dialog, scroll the listing panel until it stops
// growing (it loads ~40 at a time), then read each listing's
// "Sec X • Row Y" and all-in price. Keeps only window.__madrSections.
//
// Seats (the list only shows section and row): for listings in the rows
// that can price our seats (window.__madrSeatRows, from research_targets:
// rows near ours in our section and the comparable ones) it opens the
// listing, reads "You'll get 2 tickets together in Sec 101, Row DD, Seats
// 6-7." and closes the panel. Our row is always read; the others stop after
// 20 opens a page. The seat map shows those exactly, the rest by row.
//
// Our row (window.__madrOurs: section, row, and quantity = our open seats):
// - Ticketmaster lists only what sells at the chosen quantity: 2, which is
//   what we price. A listing of all three of our seats that only sells
//   together is hidden there (Dec 13, 2026-11-16). So when our open seats
//   aren't 2, it switches the quantity to that number afterwards and reads
//   our row again (window.__madr.quantity_check).
// The app counts a listing as ours only if it has our seats (1-3).
//
// Runs in the page via javascript_tool and returns "started" at once; the
// result lands in window.__madr (tool calls time out at 45s, so poll it).
// Stops at the first sign of a block page, or a list that stops loading
// short of Ticketmaster's own count ("stalled"). The list loads more only
// while Chromium draws the page, and Chromium doesn't draw a tab that's
// behind another tab: then it stops with "not_drawing" instead, because
// that's a local problem, not Ticketmaster. The only things it clicks:
// "Accept & Continue", the quantity filter and one of its options, a listing
// card in a row near ours, and that panel's "Close Ticket Selection" button.
// Never "Reserve Tickets" or anything else.
(() => {
  const sections = new Set(window.__madrSections || [ "101", "102", "120" ])
  const ours = window.__madrOurs || { section: "101", row: "DD" }
  const seatRows = window.__madrSeatRows || { [ours.section]: [ ours.row ] }
  const MAX_SEAT_READS = window.__madrSeatReadsMax ?? 20
  const PRICED_QUANTITY = 2
  const state = (window.__madr = { status: "running", startedAt: new Date().toISOString() })

  // setTimeout is throttled in background tabs; MessageChannel isn't.
  const sleep = (ms) => new Promise((resolve) => {
    const end = Date.now() + ms
    const channel = new MessageChannel()
    channel.port1.onmessage = () => (Date.now() >= end ? resolve() : channel.port2.postMessage(0))
    channel.port2.postMessage(0)
  })

  // Frames Chromium draws in a second: about 60 for the tab in front, even
  // with its window hidden, and 0-8 for a tab behind another one. (The page
  // still says it's visible there, because Claude in Chrome is attached.)
  const MIN_FRAMES = 20
  const framesPerSecond = async () => {
    let frames = 0
    let counting = true
    const tick = () => { if (counting) { frames += 1; requestAnimationFrame(tick) } }
    requestAnimationFrame(tick)
    await sleep(1000)
    counting = false
    return frames
  }

  const BLOCK = /pardon the interruption|browsing activity has been paused|are you a robot|captcha|access denied|unusual (?:traffic|activity)|you'?re (?:now )?in (?:the )?(?:queue|waiting room)|queue-it/i
  const blocked = () => BLOCK.test(`${document.title} ${(document.body?.innerText || "").slice(0, 4000)}`)

  // "You'll get 3 tickets together in Sec 101, Row DD, Seats 1-3."
  const SEATS = /You'll get \d+ tickets? (?:together )?in Sec (\w+), Row (\w+), Seats? (\d+)(?:\s*[-–]\s*(\d+))?/

  const listElement = () => document.querySelector('ul[aria-label^="Ticket listings"]')

  const resultsCount = () => {
    const match = document.body.innerText.match(/([\d,]+) Results?\b/)
    return match ? parseInt(match[1].replace(/,/g, ""), 10) : null
  }

  // "Open quantity filters, current quantity: 2 Tickets": the button's
  // aria-label, or its text (Ticketmaster moved it there on 2026-11-16).
  const quantityLabel = (b) => (b?.getAttribute("aria-label") || b?.textContent || "").trim()
  const quantityButton = () => [ ...document.querySelectorAll("button") ]
    .find((b) => /^Open quantity filters/i.test(quantityLabel(b)) && b.getBoundingClientRect().width > 0)

  const currentQuantity = () => {
    const match = quantityLabel(quantityButton()).match(/current quantity:\s*(\d+)/i)
    return match ? Number(match[1]) : null
  }

  // Chooses "N Tickets" in Ticketmaster's quantity menu ("Set quantity to: N
  // Tickets" radio buttons). True once the page says that quantity.
  const setQuantity = async (n) => {
    const opener = quantityButton()
    if (!opener) return false
    opener.click()
    const pattern = new RegExp(`Set quantity to:\\s*${n} Tickets?\\b`, "i")
    let option = null
    for (let i = 0; i < 20 && !option; i++) {
      await sleep(250)
      option = [ ...document.querySelectorAll('button[role="radio"]') ].find((b) => pattern.test(b.textContent))
    }
    if (!option) return false
    const before = resultsCount()
    option.click()
    for (let i = 0; i < 40 && resultsCount() === before; i++) await sleep(250)
    await sleep(1500)
    const now = currentQuantity()
    return now === null || now === n
  }

  // Scrolls the list until its count holds for four checks, or two minutes.
  // A list that stops well short of Ticketmaster's count has stalled. The
  // two seen so far (81 of 589 on 2026-11-16, 81 of 244 on 2026-11-18) were
  // tabs Chromium wasn't drawing, so a stall is checked for that first.
  const scrollAll = async () => {
    const list = listElement()
    let last = -1
    let stable = 0
    const deadline = Date.now() + 120000
    while (list && stable < 4 && Date.now() < deadline) {
      list.parentElement.scrollTop = list.parentElement.scrollHeight
      await sleep(1200)
      if (blocked()) return { blocked: true }
      const count = list.querySelectorAll("li").length
      stable = count === last ? stable + 1 : 0
      last = count
    }
    const items = list ? [ ...list.querySelectorAll("li") ] : []
    const total = resultsCount()
    return { items, total, stable, stalled: !!total && items.length < Math.floor(total * 0.95) }
  }

  const describe = (li) => {
    const text = li.innerText.replace(/\s+/g, " ").trim()
    const where = text.match(/Sec (\w+) • Row (\w+)/)
    const price = text.match(/\$([\d,]+\.\d\d)/)
    if (!where || !price) return null
    return { section: where[1], row: where[2], price: parseFloat(price[1].replace(/,/g, "")), text }
  }

  const closePanel = async () => {
    const header = [ ...document.querySelectorAll("*") ].find((el) => el.childElementCount === 0 && el.textContent.trim() === "Ticket Selection")
    let box = header
    let close = null
    for (let i = 0; i < 4 && box && !close; i++) {
      box = box.parentElement
      close = box?.querySelector("button")
    }
    if (close && /Close Ticket Selection/i.test(close.innerText)) close.click()
    for (let i = 0; i < 20 && /Ticket Selection/.test(document.body.innerText); i++) await sleep(250)
  }

  // Opens one listing's panel, reads its seats, closes it. null if unread
  // or if the panel names a different section or row.
  const readSeats = async (li, section, row) => {
    const card = li?.querySelector("button")
    if (!card) return null
    li.scrollIntoView({ block: "center" })
    card.click()
    let match = null
    for (let i = 0; i < 24 && !match; i++) {
      await sleep(250)
      match = document.body.innerText.match(SEATS)
    }
    await closePanel()
    await sleep(600)
    if (!match || match[1] !== section || match[2] !== row) return null
    const from = Number(match[3])
    const to = Number(match[4] || match[3])
    if (to < from || to - from > 20) return null
    return Array.from({ length: to - from + 1 }, (_, i) => from + i)
  }

  const seatLabel = (seats) => (seats ? ` [Seats ${seats[0]}-${seats.at(-1)}]` : "")
  const stop = (status, extra = {}) => Object.assign(state, { status, title: document.title, ...extra })
  const stopStalled = async (result) => {
    const fps = await framesPerSecond()
    return stop(fps < MIN_FRAMES ? "not_drawing" : "stalled", { fps, read: result.items.length, event_total_listings: result.total })
  }

  const run = async () => {
    for (let i = 0; i < 60 && !listElement(); i++) {
      if (blocked()) return stop("blocked")
      const accept = [ ...document.querySelectorAll("button") ].find((b) => /Accept & Continue/i.test(b.innerText))
      if (accept) accept.click()
      if (!listElement()) await sleep(500)
    }
    if (!listElement()) return stop("no_list", { text: (document.body?.innerText || "").replace(/\s+/g, " ").slice(0, 300) })

    const fps = await framesPerSecond()
    if (fps < MIN_FRAMES) return stop("not_drawing", { fps })
    state.fps = fps

    // Prices are for a pair: make sure Ticketmaster is showing 2.
    const shown = currentQuantity()
    if (shown !== null && shown !== PRICED_QUANTITY && !(await setQuantity(PRICED_QUANTITY))) {
      return stop("error", { error: `couldn't set the quantity to ${PRICED_QUANTITY}` })
    }

    const main = await scrollAll()
    if (main.blocked) return stop("blocked")
    if (main.stalled) return stopStalled(main)

    const listings = []
    main.items.forEach((li, index) => {
      const l = describe(li)
      if (!l || !sections.has(l.section)) return
      listings.push({
        position: index + 1, section: l.section, row: l.row, price: l.price,
        ticket_type: /Standard Admission/i.test(l.text) ? "standard_admission" : "verified_resale",
        raw_label: l.text.slice(0, 200)
      })
    })
    // Our row first and always (it decides whether our seats are listed),
    // then the other rows near ours up to the cap.
    const isOurs = (l) => l.section === ours.section && l.row === ours.row
    const wanted = listings.filter((l) => (seatRows[l.section] || []).includes(l.row) || isOurs(l))
    let seatReads = 0
    let seatReadsCapped = 0
    for (const listing of [ ...wanted.filter(isOurs), ...wanted.filter((l) => !isOurs(l)) ]) {
      if (!isOurs(listing) && seatReads >= MAX_SEAT_READS) {
        seatReadsCapped += 1
        continue
      }
      if (blocked()) return stop("blocked")
      listing.seats = await readSeats(main.items[listing.position - 1], listing.section, listing.row)
      listing.raw_label += seatLabel(listing.seats)
      if (!isOurs(listing)) seatReads += 1
    }

    // A listing of all our open seats together shows only at that quantity.
    let check = null
    if (ours.quantity && ours.quantity !== PRICED_QUANTITY) {
      check = { quantity: ours.quantity, complete: false, listings: [] }
      if (await setQuantity(ours.quantity)) {
        const again = await scrollAll()
        if (again.blocked) return stop("blocked")
        if (again.stalled) return stopStalled(again)
        Object.assign(check, { read: again.items.length, total: again.total, complete: again.stable >= 4 })
        for (const li of again.items) {
          const l = describe(li)
          if (!l || l.section !== ours.section || l.row !== ours.row) continue
          if (blocked()) return stop("blocked")
          const seats = await readSeats(li, ours.section, ours.row)
          check.listings.push({ price: l.price, seats, raw_label: l.text.slice(0, 160) + seatLabel(seats) })
        }
      } else {
        check.error = "couldn't switch Ticketmaster's quantity"
      }
    }

    Object.assign(state, {
      status: "done",
      title: document.title,
      read: main.items.length,
      scroll_complete: main.stable >= 4,
      event_total_listings: main.total ?? main.items.length,
      our_row: listings.filter((l) => l.section === ours.section && l.row === ours.row)
                       .map((l) => ({ price: l.price, seats: l.seats || null })),
      quantity_check: check,
      seat_reads: seatReads,
      seat_reads_capped: seatReadsCapped,
      listings
    })
  }

  // Tool output is cut off at around a thousand characters, so read the
  // result back in pieces:
  //   window.__madrMeta()       title, counts, scroll_complete, our_row, quantity_check
  //   window.__madrChunk(0, 10) [position, section, row, price, "R"|"S", label, seats]
  // ("S" = Standard Admission; the label keeps only "Sec X • Row Y ... $price";
  // seats are read only in rows near ours, else null).
  window.__madrMeta = () => JSON.stringify({
    status: state.status, title: state.title, fps: state.fps, read: state.read, kept: state.listings?.length,
    event_total_listings: state.event_total_listings, scroll_complete: state.scroll_complete,
    seat_reads: state.seat_reads, seat_reads_capped: state.seat_reads_capped,
    our_row: state.our_row, quantity_check: state.quantity_check
  })
  window.__madrChunk = (from, n) => JSON.stringify((state.listings || []).slice(from, from + n).map((l) => [
    l.position, l.section, l.row, l.price, l.ticket_type === "standard_admission" ? "S" : "R",
    (l.raw_label.match(/Sec \w+ • Row \w+.*$/) || [ l.raw_label ])[0], l.seats || null
  ]))

  run().catch((error) => Object.assign(state, { status: "error", error: String(error) }))
  return "started"
})()
