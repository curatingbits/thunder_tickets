# What the research panel on Pricing shows (research_requests/_panel):
# - research that's going (any run, the 4am runs too), with its progress;
# - an Update prices request starting or waiting for Duggan's computer;
# - otherwise the last research, the last request's problem if it had one,
#   and the two Update prices choices, or why they're off.
class ResearchPanel
  NOTE_FOR = 12.hours # how long the last request's problem stays on the panel

  attr_reader :season, :now

  def initialize(season:, now: Time.current)
    @season = season
    @now = now
  end

  # :running, :starting, :pending or :idle. Anything but idle is polled.
  def state
    @state ||=
      if live_run then :running
      elsif request&.state(now) == "starting" then :starting
      elsif request&.state(now) == "pending" then :pending
      else :idle
      end
  end

  def active?
    state != :idle
  end

  # The latest request, whatever became of it.
  def request
    return @request if defined?(@request)

    @request = ResearchRequest.recent_first.includes(:user).first
  end

  def live_run
    return @live_run if defined?(@live_run)

    @live_run = ResearchRequest.live_run(now)
  end

  # The request behind the run that's going, when it came from Update prices.
  def run_request
    return @run_request if defined?(@run_request)

    @run_request = ResearchRequest.for_run(live_run)
  end

  # [games read, games to read] for the run that's going.
  def progress
    scope = run_request&.scope || (live_run.key.end_with?("-soon") ? "soon" : "all")
    read = live_run.market_snapshots.count
    [ read, [ ResearchRequest.target_count(scope, season: season), read ].max ]
  end

  def last_run
    return @last_run if defined?(@last_run)

    @last_run = ImportRun.market_research.recent_first.first
  end

  def unavailable_reason
    return @unavailable_reason if defined?(@unavailable_reason)

    @unavailable_reason = ResearchRequest.unavailable_reason(now)
  end

  # The Update prices choices: scope, label, how many games, about how long.
  def choices
    ResearchRequest::SCOPES.map do |scope, label|
      games = ResearchRequest.target_count(scope, season: season)
      { scope: scope, label: label, games: games, estimate: estimate(games) }
    end
  end

  # What went wrong with the last request, while it's recent.
  def note
    return unless request && (settled = request.settled_at(now)) && settled > now - NOTE_FOR

    case request.state(now)
    when "expired" then request.error.presence || "The last update expired: Duggan's computer didn't pick it up within an hour. It may be off."
    when "failed" then "The last update couldn't start: #{request.error.presence || "Duggan's computer couldn't start the research."}"
    when "did_not_start" then "The last update didn't start on Duggan's computer."
    when "stopped" then "The last update stopped partway. Whatever it read is saved."
    end
  end

  private

  def estimate(games)
    minutes = games * ResearchRequest::MINUTES_PER_GAME + 2
    if minutes < 50 then "about #{(minutes / 5.0).ceil * 5} min"
    else "about #{(minutes / 60.0).round} #{"hour".pluralize((minutes / 60.0).round)}"
    end
  end
end
