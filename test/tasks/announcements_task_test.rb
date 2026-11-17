require "test_helper"
require "rake"

class AnnouncementsTaskTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("announcements:whats_new")
    @mark = User.create!(name: "Mark Augspurger", email: "mark@example.com", password: "secret123")
  end

  test "shows who the email goes to and sends nothing without SEND=yes" do
    output = nil
    assert_no_emails { output = run_whats_new("TO" => @mark.email, "FROM" => users(:admin).email) }

    assert_match(/to:\s+Mark Augspurger <mark@example.com>/, output)
    assert_match(/cc:\s+Admin User <admin@example.com>/, output)
    assert_includes output, "Dry run: nothing sent."
  end

  test "sends one email with SEND=yes" do
    output = nil
    assert_emails(1) { output = run_whats_new("TO" => @mark.email, "FROM" => users(:admin).email, "SEND" => "yes") }

    assert_includes output, "Sent"
    assert_equal [ "mark@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  test "stops unless both people are active users" do
    @mark.update!(active: false)

    assert_no_emails do
      assert_raises(SystemExit) { run_whats_new("TO" => @mark.email, "FROM" => users(:admin).email, "SEND" => "yes") }
      assert_raises(SystemExit) { run_whats_new("TO" => "nobody@example.com", "FROM" => users(:admin).email, "SEND" => "yes") }
    end
  end

  private
    # Runs the task with these environment variables and returns what it printed.
    def run_whats_new(env)
      saved = env.keys.index_with { |key| ENV[key] }
      env.each { |key, value| ENV[key] = value }
      capture_io { Rake::Task["announcements:whats_new"].invoke }.first
    ensure
      saved.each { |key, value| ENV[key] = value }
      Rake::Task["announcements:whats_new"].reenable
    end
end
