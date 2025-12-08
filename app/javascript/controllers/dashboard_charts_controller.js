import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

export default class extends Controller {
  static targets = ["profitChart"]

  connect() {
    if (this.hasProfitChartTarget) {
      this.initProfitChart()
    }
  }

  disconnect() {
    if (this.profitChartInstance) {
      this.profitChartInstance.destroy()
    }
  }

  initProfitChart() {
    const canvas = this.profitChartTarget
    const gameData = JSON.parse(canvas.dataset.gameProfits || "[]")

    if (gameData.length === 0) return

    const ctx = canvas.getContext("2d")

    const labels = gameData.map(g => g.opponent)
    const profits = gameData.map(g => g.profit)
    const revenues = gameData.map(g => g.revenue)

    // Create gradient backgrounds for bars
    const profitColors = profits.map(p => p >= 0 ? "rgba(34, 197, 94, 0.8)" : "rgba(239, 68, 68, 0.8)")
    const profitBorders = profits.map(p => p >= 0 ? "rgba(34, 197, 94, 1)" : "rgba(239, 68, 68, 1)")

    this.profitChartInstance = new Chart(ctx, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Profit/Loss",
            data: profits,
            backgroundColor: profitColors,
            borderColor: profitBorders,
            borderWidth: 1,
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
            backgroundColor: "rgba(17, 24, 39, 0.95)",
            titleColor: "#fff",
            bodyColor: "#d1d5db",
            borderColor: "rgba(75, 85, 99, 0.5)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            displayColors: false,
            callbacks: {
              title: function(context) {
                const idx = context[0].dataIndex
                return `vs ${gameData[idx].opponent}`
              },
              label: function(context) {
                const idx = context.dataIndex
                const game = gameData[idx]
                const profit = game.profit
                const sign = profit >= 0 ? "+" : ""
                return [
                  `Profit: ${sign}$${profit.toLocaleString()}`,
                  `Revenue: $${game.revenue.toLocaleString()}`,
                  `Cost: $${game.cost.toLocaleString()}`,
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
              color: "#9ca3af",
              font: {
                size: 11
              },
              maxRotation: 45,
              minRotation: 45
            }
          },
          y: {
            grid: {
              color: "rgba(75, 85, 99, 0.3)",
              drawBorder: false
            },
            ticks: {
              color: "#9ca3af",
              font: {
                size: 11
              },
              callback: function(value) {
                if (value >= 1000 || value <= -1000) {
                  return "$" + (value / 1000).toFixed(0) + "k"
                }
                return "$" + value
              }
            },
            beginAtZero: true
          }
        }
      }
    })
  }
}
