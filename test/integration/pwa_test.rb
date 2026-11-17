require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "the manifest is public and describes an installable app" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "MADR Tickets", manifest["name"]
    assert_equal "standalone", manifest["display"]
    assert_equal "/", manifest["start_url"]
    assert_equal [ "192x192", "512x512" ], manifest["icons"].map { |i| i["sizes"] }.uniq
    assert_equal [ "/icon-maskable.png" ], manifest["icons"].select { |i| i["purpose"] == "maskable" }.map { |i| i["src"] }
    manifest["icons"].each do |i|
      assert File.exist?(Rails.root.join("public", i["src"].delete_prefix("/"))), "missing #{i["src"]}"
    end
  end

  test "the service worker is public and falls back to the offline page" do
    get pwa_service_worker_path(format: :js)

    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, "/offline.html"
    assert File.exist?(Rails.root.join("public/offline.html"))
  end

  test "pages link the manifest and fit the phone screen" do
    sign_in
    get root_path

    assert_select "link[rel=manifest][href=?]", "/manifest.json"
    assert_select "meta[name=theme-color][content=?]", "#16161e"
    assert_select "meta[name=viewport][content*=?]", "viewport-fit=cover"
  end

  test "pages carry the logo, favicon and home-screen icon" do
    sign_in
    get root_path

    assert_select "link[rel=icon][type='image/svg+xml'][href=?]", "/favicon.svg"
    assert_select "link[rel=icon][type='image/png'][href=?]", "/favicon-32.png"
    assert_select "link[rel=apple-touch-icon][href=?]", "/apple-touch-icon.png"
    %w[favicon.svg favicon-32.png apple-touch-icon.png].each { |f| assert File.exist?(Rails.root.join("public", f)), "missing #{f}" }
    assert_select "[data-shell=sidebar] a[href='/'] svg[aria-label=?]", "MADR Tickets"
    assert_select "[data-shell=top-bar] a[href='/'] svg[aria-label=?]", "MADR Tickets"
    assert_select "svg[aria-label='MADR Tickets'] [id]", false, "the logo has no ids, so it can appear twice on a page"
  end
end
