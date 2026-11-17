require "test_helper"

class AnnouncementMailerTest < ActionMailer::TestCase
  setup do
    @mark = User.create!(name: "Mark Augspurger", email: "mark@example.com", password: "secret123")
    @duggan = users(:admin)
  end

  test "what's new goes to the recipient from the app, copying the sender, who gets the replies" do
    email = AnnouncementMailer.with(recipient: @mark, sender: @duggan).whats_new

    assert_equal "Six new things in MADR Tickets", email.subject
    assert_equal [ "noreply@madrtickets.com" ], email.from
    assert_equal [ "MADR Tickets" ], email[:from].display_names
    assert_equal [ "mark@example.com" ], email.to
    assert_equal [ @duggan.email ], email.cc
    assert_equal [ @duggan.email ], email.reply_to
    assert_equal({ idempotency_key: "whats-new-2026-11-17/#{@mark.id}" }, email[:options].unparsed_value)
  end

  test "what's new shows screenshots the site serves, and links into the app" do
    email = AnnouncementMailer.with(recipient: @mark, sender: @duggan).whats_new
    html = email.html_part.body.to_s

    images = html.scan(/<img src="([^"]+)"/).flatten
    assert_equal %w[header pricing map money dashboard signin icon].map { "http://example.com/emails/whats-new-2026-11-17/#{_1}.png" }, images
    images.each { |url| assert Rails.public_path.join(URI(url).path.delete_prefix("/")).file?, "#{url} isn't in public/" }

    [ "http://example.com/pricing", "http://example.com/pricing/map", "http://example.com/money" ].each do |url|
      assert_includes html, %(href="#{url}")
      assert_includes email.text_part.body.to_s, url
    end
    assert_includes email.text_part.body.to_s, "Prices update every Monday and Wednesday morning for now"
  end
end
