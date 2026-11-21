# Someone pressed Update prices on the Pricing page. The research runs on
# Duggan's computer (Claude driving the logged-out research browser), which
# the website can't reach, so the request waits here. Every two minutes the
# computer asks for one (bin/research-requests in the ticketmaster-pricing
# skill), claims it, and starts the research with the run key "tm-req-<id>",
# which is how a request finds its ImportRun.
#
# Each run reads Ticketmaster and keeps Claude busy for about two minutes a
# game, so there are limits:
# - one at a time;
# - at most DAILY_LIMIT runs a day;
# - none for BLOCK_PAUSE after Ticketmaster blocks a run (the research never
#   retries a block);
# - a request the computer doesn't pick up within EXPIRES_AFTER lapses, so
#   turning the computer on later doesn't start a run nobody is waiting for.
class ResearchRequest < ApplicationRecord
  SCOPES = { "soon" => "Next 7 days", "all" => "All games" }.freeze
  STATUSES = %w[pending claimed cancelled expired failed].freeze
  SOON_DAYS = 7 # the same week as research_targets?within_days=7
  EXPIRES_AFTER = 1.hour
  START_TIMEOUT = 15.minutes # claimed, and still no run by then: it didn't start
  DAILY_LIMIT = 2
  BLOCK_PAUSE = 24.hours
  KEY_PREFIX = "tm-req-".freeze
  MINUTES_PER_GAME = 2 # what a run takes, about (35 games took about an hour on 2026-11-18)

  class Refused < StandardError; end

  belongs_to :user

  validates :scope, inclusion: { in: SCOPES.keys }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :claimed, -> { where(status: "claimed") }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :without_run, -> { where("NOT EXISTS (SELECT 1 FROM import_runs WHERE import_runs.key = ? || research_requests.id)", KEY_PREFIX) }

  # Records a request, or raises Refused saying why one can't be made now.
  def self.request!(user:, scope:, now: Time.current)
    raise Refused, "Choose Next 7 days or All games." unless SCOPES.key?(scope)

    transaction do
      expire_stale!(now)
      reason = unavailable_reason(now)
      raise Refused, reason if reason

      create!(user: user, scope: scope)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Refused, "An update is already waiting for Duggan's computer."
  end

  # Why a new request can't be made right now, or nil when one can.
  def self.unavailable_reason(now = Time.current)
    if (waiting = pending.where(created_at: (now - EXPIRES_AFTER)..).first)
      "#{waiting.user.name}'s update is already waiting for Duggan's computer."
    elsif starting(now).exists?
      "An update is starting on Duggan's computer."
    elsif live_run(now)
      "Research is already running."
    elsif (blocked = recent_block(now))
      "Ticketmaster blocked the last run, so updates are paused until " \
        "#{(blocked.finished_at + BLOCK_PAUSE).strftime('%a %-l:%M %p')}."
    elsif runs_today(now) >= DAILY_LIMIT
      "#{DAILY_LIMIT} updates have already run today. The next can start tomorrow."
    end
  end

  # The computer's side: the oldest waiting request, now claimed, or nil and
  # why there's nothing to start. A request waits while another run is going.
  def self.claim!(client_id:, now: Time.current)
    transaction do
      expire_stale!(now)
      request = pending.order(:created_at, :id).first
      return [ nil, "nothing is waiting" ] unless request
      if (run = live_run(now))
        return [ nil, "research is already running (#{run.key})" ]
      end
      if recent_block(now)
        request.update!(status: "expired", error: "Ticketmaster blocked a run after this was asked for.")
        return [ nil, "Ticketmaster blocked a run, so updates are paused" ]
      end

      request.update!(status: "claimed", claimed_at: now, client_id: client_id)
      [ request, nil ]
    end
  end

  # Settles requests that time ran out on: waiting too long, or claimed
  # without a run ever starting.
  def self.expire_stale!(now = Time.current)
    pending.where(created_at: ...(now - EXPIRES_AFTER)).update_all(status: "expired", updated_at: now)
    claimed.where(claimed_at: ...(now - START_TIMEOUT)).without_run
           .update_all(status: "failed", error: "Duggan's computer didn't start the research.", updated_at: now)
  end

  def self.starting(now = Time.current)
    claimed.where(claimed_at: (now - START_TIMEOUT)..).without_run
  end

  # A research run that's going: any kind (the 4am runs too), still checking in.
  def self.live_run(now = Time.current)
    ImportRun.market_research.where(status: "running").where(last_activity_at: (now - ImportRun::LEASE)..).first
  end

  def self.recent_block(now = Time.current)
    ImportRun.market_research.where(status: "blocked", finished_at: (now - BLOCK_PAUSE)..).order(finished_at: :desc).first
  end

  # Runs started from Update prices today. Requests that never ran don't count.
  def self.runs_today(now = Time.current)
    ImportRun.market_research.where("key LIKE ?", "#{KEY_PREFIX}%").where(started_at: now.beginning_of_day..).count
  end

  # How many games a run of this scope would read, as research_targets lists them.
  def self.target_count(scope, season:, today: Date.current)
    games = season.games.where(game_date: today..)
    games = games.where(game_date: ..today + SOON_DAYS) if scope == "soon"
    games.count
  end

  def self.for_run(run)
    id = run&.key&.delete_prefix(KEY_PREFIX)
    find_by(id: id) if run&.key&.start_with?(KEY_PREFIX) && id.match?(/\A\d+\z/)
  end

  def run_key
    "#{KEY_PREFIX}#{id}"
  end

  def run
    return @run if defined?(@run)

    @run = ImportRun.find_by(key: run_key)
  end

  def reload(*)
    remove_instance_variable(:@run) if defined?(@run)
    super
  end

  def scope_label
    SCOPES.fetch(scope)
  end

  def within_days
    SOON_DAYS if scope == "soon"
  end

  # Where it's got to:
  # - pending: waiting for the computer; expired: it never picked it up;
  # - cancelled; failed: the computer couldn't start it;
  # - starting: claimed, no run yet; did_not_start: still none after START_TIMEOUT;
  # - running; stopped: its run stopped checking in; finished: its run ended.
  def state(now = Time.current)
    case status
    when "pending" then created_at > now - EXPIRES_AFTER ? "pending" : "expired"
    when "claimed"
      if run.nil? then claimed_at > now - START_TIMEOUT ? "starting" : "did_not_start"
      elsif run.running? then run.lease_expired?(now) ? "stopped" : "running"
      else "finished"
      end
    else status
    end
  end

  # When it stopped being active, or nil while it still is.
  def settled_at(now = Time.current)
    case state(now)
    when "finished" then run.finished_at
    when "stopped" then run.last_activity_at + ImportRun::LEASE
    when "did_not_start" then claimed_at + START_TIMEOUT
    when "expired" then status == "pending" ? created_at + EXPIRES_AFTER : updated_at
    when "cancelled", "failed" then updated_at
    end
  end

  def cancel!(now: Time.current)
    raise Refused, "Only an update that's still waiting can be cancelled." unless state(now) == "pending"

    update!(status: "cancelled")
  end

  # The computer couldn't start the research it claimed.
  def fail!(error)
    raise Refused, "Only a claimed request can fail." unless status == "claimed"

    update!(status: "failed", error: error.to_s.first(300))
  end
end
