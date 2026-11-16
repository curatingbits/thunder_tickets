import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

// Chart colors come from the theme's CSS custom properties
// (app/assets/tailwind/application.css), so the charts follow the design
// tokens instead of carrying their own hex values.
function token(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(`--color-${name}`).trim()
}

// "#rrggbb" + alpha -> "rgba(...)". Chart.js parses colors to derive hover
// shades, so it needs plain hex/rgb rather than color-mix().
function withAlpha(hex, alpha) {
  const match = /^#([0-9a-f]{6})$/i.exec(hex)
  if (!match) return hex
  const n = parseInt(match[1], 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`
}

// Money arrives as strings (Rails serializes BigDecimal that way), so every
// formatter coerces with Number() first.
function currency(value) {
  return `$${Math.round(Number(value)).toLocaleString()}`
}

// Mirrors ApplicationHelper#signed_currency: "+$1,234", "-$390", "$0".
function signedCurrency(value) {
  const rounded = Math.round(Number(value))
  const formatted = `$${Math.abs(rounded).toLocaleString()}`
  if (rounded > 0) return `+${formatted}`
  if (rounded < 0) return `-${formatted}`
  return formatted
}

// Axis ticks: "$500", "-$50", "$2k", "-$1k".
function axisCurrency(value) {
  const sign = value < 0 ? "-" : ""
  const abs = Math.abs(value)
  return abs >= 1000 ? `${sign}$${(abs / 1000).toFixed(0)}k` : `${sign}$${abs}`
}

export default class extends Controller {
  static targets = ["profitChart", "revenueChart"]

  connect() {
    this.colors = {
      positive: token("chart-positive"),
      negative: token("chart-negative"),
      neutral: token("chart-neutral"),
      reference: token("muted"),
      tooltipBg: token("surface-raised"),
      tooltipBorder: token("subtle"),
      text: token("content"),
      textStrong: token("content-strong"),
      textDim: token("content-dim"),
      axis: token("muted"),
      grid: token("subtle")
    }

    if (this.hasProfitChartTarget) {
      this.initProfitChart()
    }
    if (this.hasRevenueChartTarget) {
      this.initRevenueChart()
    }
  }

  disconnect() {
    if (this.profitChartInstance) {
      this.profitChartInstance.destroy()
    }
    if (this.revenueChartInstance) {
      this.revenueChartInstance.destroy()
    }
  }

  // Shared tooltip chrome: surface + text tokens, never series colors.
  tooltipStyle() {
    return {
      backgroundColor: this.colors.tooltipBg,
      titleColor: this.colors.textStrong,
      bodyColor: this.colors.text,
      borderColor: this.colors.tooltipBorder,
      borderWidth: 1,
      padding: 12,
      cornerRadius: 8
    }
  }

  currencyAxis() {
    return {
      grid: {
        color: this.colors.grid,
        drawBorder: false
      },
      ticks: {
        color: this.colors.axis,
        font: {
          size: 11
        },
        callback: axisCurrency
      },
      beginAtZero: true
    }
  }

  initProfitChart() {
    const canvas = this.profitChartTarget
    const gameData = JSON.parse(canvas.dataset.gameProfits || "[]")

    if (gameData.length === 0) return

    const ctx = canvas.getContext("2d")

    const labels = gameData.map(g => g.opponent)
    const profits = gameData.map(g => Number(g.profit))

    // Polarity: profit green, loss red. A game not yet played with nothing
    // sold is neutral: its bar is cost not yet recovered, not a loss.
    const barColors = gameData.map((g, i) => {
      if (g.pending) return this.colors.neutral
      if (profits[i] > 0) return this.colors.positive
      if (profits[i] < 0) return this.colors.negative
      return this.colors.neutral
    })

    this.profitChartInstance = new Chart(ctx, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Profit/Loss",
            data: profits,
            backgroundColor: barColors,
            borderWidth: 0,
            borderRadius: 4,
            barPercentage: 0.7,
            categoryPercentage: 0.8
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            ...this.tooltipStyle(),
            displayColors: false,
            callbacks: {
              title: function(context) {
                const idx = context[0].dataIndex
                return `vs ${gameData[idx].opponent}`
              },
              label: function(context) {
                const game = gameData[context.dataIndex]
                if (game.pending) {
                  return [
                    "Not sold yet",
                    `Cost: ${currency(game.cost)}`
                  ]
                }
                return [
                  `Profit: ${signedCurrency(game.profit)}`,
                  `Revenue: ${currency(game.revenue)}`,
                  `Cost: ${currency(game.cost)}`,
                  `Tickets: ${game.tickets_sold} sold`
                ]
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: this.colors.axis,
              font: {
                size: 11
              },
              maxRotation: 45,
              minRotation: 45
            }
          },
          y: this.currencyAxis()
        }
      }
    })
  }

  initRevenueChart() {
    const canvas = this.revenueChartTarget
    const data = JSON.parse(canvas.dataset.monthlyFinancials || "[]")

    if (data.length === 0) return

    const ctx = canvas.getContext("2d")

    const labels = data.map(d => this.formatMonth(d.month))
    const cumulativeRevenue = data.map(d => Number(d.cumulative_revenue))
    const cumulativeCost = data.map(d => Number(d.cumulative_cost))

    this.revenueChartInstance = new Chart(ctx, {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Cumulative Revenue",
            data: cumulativeRevenue,
            borderColor: this.colors.positive,
            backgroundColor: withAlpha(this.colors.positive, 0.15),
            fill: true,
            tension: 0.3,
            pointRadius: 3,
            pointBackgroundColor: this.colors.positive
          },
          {
            // Cost is the line revenue has to clear, not bad news: a neutral
            // dashed reference, never red.
            label: "Cumulative Cost",
            data: cumulativeCost,
            borderColor: this.colors.reference,
            borderDash: [6, 4],
            fill: false,
            tension: 0.3,
            pointRadius: 3,
            pointBackgroundColor: this.colors.reference
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            display: true,
            labels: {
              color: this.colors.textDim,
              usePointStyle: true,
              padding: 16,
              font: {
                size: 12
              }
            }
          },
          tooltip: {
            ...this.tooltipStyle(),
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${currency(context.parsed.y)}`
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: this.colors.axis,
              font: {
                size: 11
              }
            }
          },
          y: this.currencyAxis()
        }
      }
    })
  }

  // "2025-11" -> "Nov '25"
  formatMonth(month) {
    const [year, mon] = month.split("-")
    const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    const idx = parseInt(mon, 10) - 1
    const name = names[idx] || month
    return `${name} '${year.slice(2)}`
  }
}
