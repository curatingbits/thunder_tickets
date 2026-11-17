// Reads one Ticketmaster event page the way Kate did on 2026-11-16:
// accept the purchase-policy dialog, scroll the listing panel until it stops
// growing (it loads ~40 at a time), then read each listing's
// "Sec X • Row Y" and all-in price. Keeps only window.__madrSections.
//
// Our row (window.__madrOurs, default Section 101 Row DD): the list doesn't
// show seat numbers, so it opens each listing there, reads "You'll get 2
// tickets together in Sec 101, Row DD, Seats 6-7." and closes the panel. The
// app counts a listing as ours only if it has our seats (1-3).
//
// Runs in the page via javascript_tool and returns "started" at once; the
// result lands in window.__madr (tool calls time out at 45s, so poll it).
// Stops at the first sign of a block page and says so. The only things it
// clicks: "Accept & Continue", a listing card in our row, and that panel's
// "Close Ticket Selection" button. Never "Reserve Tickets" or anything else.
(() => {
  const sections = new Set(window.__madrSections || [ "101", "102", "120" ])
  const ours = window.__madrOurs || { section: "101", row: "DD" }
  const state = (window.__madr = { status: "running", startedAt: new Date().toISOString() })

  // setTimeout is throttled in background tabs; MessageChannel isn't.
  const sleep = (ms) => new Promise((resolve) => {
    const end = Date.now() + ms
    const channel = new MessageChannel()
    channel.port1.onmessage = () => (Date.now() >= end ? resolve() : channel.port2.postMessage(0))
    channel.port2.postMessage(0)
  })

  const BLOCK = /pardon the interruption|browsing activity has been paused|are you a robot|captcha|access denied|unusual (?:traffic|activity)|you'?re (?:now )?in (?:the )?(?:queue|waiting room)|queue-it/i
  const blocked = () => BLOCK.test(`${document.title} ${(document.body?.innerText || "").slice(0, 4000)}`)

  // "You'll get 2 tickets together in Sec 101, Row DD, Seats 6-7."
  const SEATS = /You'll get \d+ tickets? (?:together )?in Sec (\w+), Row (\w+), Seats? (\d+)(?:\s*[-–]\s*(\d+))?/

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

  // Opens one listing's panel, reads its seats, closes it. null if unread.
  const readSeats = async (li) => {
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
    if (!match || match[1] !== ours.section || match[2] !== ours.row) return null
    const from = Number(match[3])
    const to = Number(match[4] || match[3])
    if (to < from || to - from > 20) return null
    return Array.from({ length: to - from + 1 }, (_, i) => from + i)
  }

  const run = async () => {
    let list = null
    for (let i = 0; i < 60 && !list; i++) {
      if (blocked()) return Object.assign(state, { status: "blocked", title: document.title })
      const accept = [ ...document.querySelectorAll("button") ].find((b) => /Accept & Continue/i.test(b.innerText))
      if (accept) accept.click()
      list = document.querySelector('ul[aria-label^="Ticket listings"]')
      if (!list) await sleep(500)
    }
    if (!list) {
      return Object.assign(state, { status: "no_list", title: document.title,
                                    text: (document.body?.innerText || "").replace(/\s+/g, " ").slice(0, 300) })
    }

    // Scroll until the count holds for four checks, or two minutes pass.
    let last = -1
    let stable = 0
    const deadline = Date.now() + 120000
    while (stable < 4 && Date.now() < deadline) {
      const scroller = list.parentElement
      scroller.scrollTop = scroller.scrollHeight
      await sleep(1200)
      if (blocked()) return Object.assign(state, { status: "blocked", title: document.title })
      const count = list.querySelectorAll("li").length
      stable = count === last ? stable + 1 : 0
      last = count
    }

    const items = [ ...list.querySelectorAll("li") ]
    const results = (document.body.innerText.match(/([\d,]+) Results/) || [])[1]
    const total = results ? parseInt(results.replace(/,/g, ""), 10) : null
    // A list that stops growing well short of Ticketmaster's own count has
    // stalled (seen 2026-11-16: 81 of 589 after several visits in a row).
    // That's Ticketmaster holding back, not a complete read: stop here.
    if (total && items.length < Math.floor(total * 0.95)) {
      return Object.assign(state, { status: "stalled", title: document.title, read: items.length, event_total_listings: total })
    }
    const listings = []
    items.forEach((li, index) => {
      const text = li.innerText.replace(/\s+/g, " ").trim()
      const where = text.match(/Sec (\w+) • Row (\w+)/)
      const price = text.match(/\$([\d,]+\.\d\d)/)
      if (!where || !price || !sections.has(where[1])) return
      listings.push({
        position: index + 1,
        section: where[1],
        row: where[2],
        price: parseFloat(price[1].replace(/,/g, "")),
        ticket_type: /Standard Admission/i.test(text) ? "standard_admission" : "verified_resale",
        raw_label: text.slice(0, 200)
      })
    })
    for (const listing of listings) {
      if (listing.section !== ours.section || listing.row !== ours.row) continue
      if (blocked()) return Object.assign(state, { status: "blocked", title: document.title })
      listing.seats = await readSeats(items[listing.position - 1])
      if (listing.seats) listing.raw_label = `${listing.raw_label} [Seats ${listing.seats[0]}-${listing.seats.at(-1)}]`
    }

    Object.assign(state, {
      status: "done",
      title: document.title,
      read: items.length,
      scroll_complete: stable >= 4,
      event_total_listings: total ?? items.length,
      our_row: listings.filter((l) => l.section === ours.section && l.row === ours.row)
                       .map((l) => ({ price: l.price, seats: l.seats || null })),
      listings
    })
  }

  // Tool output is cut off at around a thousand characters, so read the
  // result back in pieces:
  //   window.__madrMeta()       title, counts, scroll_complete
  //   window.__madrChunk(0, 10) [position, section, row, price, "R"|"S", label, seats]
  // ("S" = Standard Admission; the label keeps only "Sec X • Row Y ... $price";
  // seats are read only in our row, else null).
  window.__madrMeta = () => JSON.stringify({
    status: state.status, title: state.title, read: state.read, kept: state.listings?.length,
    event_total_listings: state.event_total_listings, scroll_complete: state.scroll_complete, our_row: state.our_row
  })
  window.__madrChunk = (from, n) => JSON.stringify((state.listings || []).slice(from, from + n).map((l) => [
    l.position, l.section, l.row, l.price, l.ticket_type === "standard_admission" ? "S" : "R",
    (l.raw_label.match(/Sec \w+ • Row \w+.*$/) || [ l.raw_label ])[0], l.seats || null
  ]))

  run().catch((error) => Object.assign(state, { status: "error", error: String(error) }))
  return "started"
})()
