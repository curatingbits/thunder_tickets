// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Makes the app installable (Add to Home Screen) and shows the offline page
// when there's no connection. See app/views/pwa/service-worker.js.
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js").catch(() => {})
}
