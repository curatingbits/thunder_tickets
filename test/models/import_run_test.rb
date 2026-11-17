require "test_helper"

class ImportRunTest < ActiveSupport::TestCase
  def start(key: "tm-1", client: "a", now: Time.current)
    ImportRun.start!(kind: "market_research", source: "ticketmaster_browser", key: key, client_id: client, now: now)
  end

  test "a new key creates a run held by its client" do
    run, outcome = start
    assert_equal :created, outcome
    assert run.running?
    assert run.held_by?("a")
  end

  test "the same client resumes; another waits out the lease, then takes over" do
    run, = start
    assert_equal :resumed, start.last

    assert_raises(ImportRun::Conflict) { start(client: "b") }

    later = Time.current + ImportRun::LEASE + 1.minute
    taken, outcome = start(client: "b", now: later)
    assert_equal [ run, :resumed, "b" ], [ taken, outcome, taken.lease_owner ]
  end

  test "only one run of a kind at a time; a stale one is abandoned" do
    first, = start
    assert_raises(ImportRun::Conflict) { start(key: "tm-2", client: "b") }

    later = Time.current + ImportRun::LEASE + 1.minute
    second, = start(key: "tm-2", client: "b", now: later)
    assert second.running?
    assert_equal "abandoned", first.reload.status
  end

  test "finishing with fewer scans than targets is partial, and a partial run can be reopened" do
    run, = start
    run.finish!("completed", targeted: 3)
    assert_equal "partial", run.status
    assert_equal({ "targeted" => 3, "scanned" => 0 }, run.stats)

    reopened, = start
    assert reopened.running?
  end

  test "a completed run can't be restarted under its key" do
    run, = start
    run.finish!("completed")
    assert_raises(ImportRun::Conflict) { start }
  end
end

class ApiTokenTest < ActiveSupport::TestCase
  test "the raw token is shown once; only its digest is stored" do
    token, raw = ApiToken.generate!(name: "research", scopes: [ "market:write" ])

    assert raw.start_with?("madr_")
    assert_equal ApiToken.digest(raw), token.token_digest
    assert_not_includes token.attributes.values.map(&:to_s), raw
    assert_equal token, ApiToken.authenticate(raw)
    assert token.reload.last_used_at.present?
  end

  test "revoked, expired, unknown and blank tokens don't authenticate" do
    token, raw = ApiToken.generate!(name: "research", scopes: [ "market:write" ])
    assert_nil ApiToken.authenticate("madr_nope")
    assert_nil ApiToken.authenticate("")

    token.revoke!
    assert_nil ApiToken.authenticate(raw)

    _, expiring = ApiToken.generate!(name: "old", scopes: [ "read" ], expires_at: 1.minute.ago)
    assert_nil ApiToken.authenticate(expiring)
  end

  test "scopes must be known" do
    assert_raises(ActiveRecord::RecordInvalid) { ApiToken.generate!(name: "x", scopes: [ "admin" ]) }
    token, = ApiToken.generate!(name: "x", scopes: [ "market:write", "read" ])
    assert token.allows?("read")
    assert_not token.allows?("settlements:write")
  end
end
