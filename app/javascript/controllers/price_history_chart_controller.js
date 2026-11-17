import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

// One game's market over time (Market::PriceHistory): market value with its
// competitive-to-premium range, and our all-in price when we had one listed.
// Colors come from the theme tokens (--color-chart-series-1/2 were checked
// with the dataviz palette validator in both themes); text stays on the
// text tokens. The table under the chart has the same numbers.

function token(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(`--color-${name}`).trim()
}

// "#rrggbb" + alpha -> "rgba(...)": Chart.js needs parseable colors.
function withAlpha(hex, alpha) {
  const match = /^#([0-9a-f]{6})$/i.exec(hex)
  if (!match) return hex
  const n = parseInt(match[1], 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`
}

function money(value) {
  return value == null ? "—" : `$${Math.round(Number(value)).toLocaleString()}`
}

const RANGE = "Range (competitive to premium)"
const RANGE_LOW = "range-low"

export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    this.render()
    this.rerender = () => {
      this.chart?.destroy()
      this.render()
    }
    window.addEventListener("theme:change", this.rerender)
    this.colorScheme = window.matchMedia("(prefers-color-scheme: light)")
    this.colorScheme.addEventListener("change", this.rerender)
  }

  disconnect() {
    window.removeEventListener("theme:change", this.rerender)
    this.colorScheme.removeEventListener("change", this.rerender)
    this.chart?.destroy()
    this.chart = null
  }

  render() {
    const points = JSON.parse(this.canvasTarget.dataset.points || "[]")
    if (points.length < 2) return

    const market = token("chart-series-1")
    const ours = token("chart-series-2")
    const surface = token("surface")
    const text = token("content")
    const axis = token("muted")
    const grid = token("subtle")

    const datasets = [
      // The band: the premium line filled down to the competitive line.
      { label: RANGE, data: points.map(p => p.high), fill: "+1", backgroundColor: withAlpha(market, 0.16),
        borderWidth: 0, pointRadius: 0, pointHitRadius: 0, order: 3 },
      { label: RANGE_LOW, data: points.map(p => p.low), fill: false, borderWidth: 0, pointRadius: 0, pointHitRadius: 0, order: 3 },
      { label: "Market value", data: points.map(p => p.market), borderColor: market, backgroundColor: market,
        borderWidth: 2, pointRadius: 4, pointHoverRadius: 6, pointBorderColor: surface, pointBorderWidth: 2, order: 1 }
    ]
    if (points.some(p => p.ours != null)) {
      datasets.push({ label: "Our price", data: points.map(p => p.ours), borderColor: ours, backgroundColor: ours,
        borderWidth: 2, borderDash: [6, 4], pointStyle: "rectRot", pointRadius: 5, pointHoverRadius: 7,
        pointBorderColor: surface, pointBorderWidth: 2, spanGaps: false, order: 0 })
    }

    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: { labels: points.map(p => p.label), datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              color: text, usePointStyle: true, boxWidth: 8, boxHeight: 8, padding: 14,
              filter: item => item.text !== RANGE_LOW,
              // The band's own fill is too faint for a legend swatch.
              generateLabels: chart => Chart.defaults.plugins.legend.labels.generateLabels(chart).map(item =>
                item.text === RANGE
                  ? { ...item, pointStyle: "rect", fillStyle: withAlpha(market, 0.35), strokeStyle: withAlpha(market, 0.7), lineWidth: 1 }
                  : item)
            }
          },
          tooltip: {
            backgroundColor: token("surface-raised"),
            titleColor: token("content-strong"),
            bodyColor: text,
            borderColor: grid,
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            filter: item => item.dataset.label !== RANGE && item.dataset.label !== RANGE_LOW,
            callbacks: {
              title: items => {
                const p = points[items[0].dataIndex]
                return `${p.label} · ${p.days} days before the game`
              },
              label: item => `${item.dataset.label}: ${money(item.parsed.y)} all-in`,
              afterBody: items => {
                const p = points[items[0].dataIndex]
                return [`Range: ${money(p.low)} to ${money(p.high)}`, `List at: ${money(p.list)}`]
              }
            }
          }
        },
        scales: {
          x: { grid: { display: false }, ticks: { color: axis, font: { size: 11 } } },
          y: { grid: { color: grid }, border: { display: false },
               ticks: { color: axis, font: { size: 11 }, callback: value => `$${value}` } }
        }
      }
    })
  }
}
