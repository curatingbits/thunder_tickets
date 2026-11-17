// Reads one Ticketmaster event page the way Kate did on 2026-11-16:
// accept the purchase-policy dialog, scroll the listing panel until it stops
// growing (it loads ~40 at a time), then read each listing's
// "Sec X • Row Y" and all-in price. Keeps only window.__madrSections.
//
// Runs in the page via javascript_tool and returns "started" at once; the
// result lands in window.__madr (tool calls time out at 45s, so poll it).
// Stops at the first sign of a block page and says so. Never clicks anything
// but "Accept & Continue".
(() => {
  const sections = new Set(window.__madrSections || [ "101", "102", "120" ])
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
    const results = (document.body.innerText.match(/([\d,]+) Results/) || [])[1]
    Object.assign(state, {
      status: "done",
      title: document.title,
      read: items.length,
      scroll_complete: stable >= 4,
      event_total_listings: results ? parseInt(results.replace(/,/g, ""), 10) : items.length,
      listings
    })
  }

  run().catch((error) => Object.assign(state, { status: "error", error: String(error) }))
  return "started"
})()
