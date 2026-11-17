# One data run (Ticketmaster research, Venmo sync). The key makes a run
# idempotent (a skill can resume it after a crash), and the lease keeps two
# clients from running the same kind at once: a client holds it by sending
# its client_id, every write renews it, and after LEASE of silence another
# client may take over.
class ImportRun < ApplicationRecord
  KINDS = %w[market_research payment_sync].freeze
  STATUSES = %w[running completed partial blocked failed abandoned].freeze
  FINISHED = %w[completed partial blocked failed abandoned].freeze
  REOPENABLE = %w[partial blocked].freeze
  LEASE = 20.minutes
  REOPEN_WINDOW = 7.days

  class Conflict < StandardError; end

  belongs_to :api_token, optional: true
  belongs_to :user, optional: true
  has_many :market_snapshots, dependent: :restrict_with_error

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :key, presence: true, uniqueness: true
  validates :source, presence: true

  scope :recent_first, -> { order(started_at: :desc) }
  scope :market_research, -> { where(kind: "market_research") }

  # Start a run, or resume the one with this key. Returns [run, :created |
  # :resumed]. Raises Conflict when another client holds a live lease, or the
  # key belongs to a finished run that can't be reopened.
  def self.start!(kind:, source:, key:, client_id:, now: Time.current, **attrs)
    transaction do
      where(kind: kind, status: "running").where("last_activity_at IS NULL OR last_activity_at < ?", now - LEASE)
        .where.not(key: key).find_each { |stale| stale.update!(status: "abandoned", finished_at: now) }

      if (run = find_by(key: key))
        [ run.resume!(client_id, now: now), :resumed ]
      else
        if where(kind: kind, status: "running").exists?
          raise Conflict, "another #{kind.humanize(capitalize: false)} run is in progress"
        end

        [ create!(kind: kind, source: source, key: key, lease_owner: client_id, last_activity_at: now,
                  started_at: now, **attrs), :created ]
      end
    end
  end

  def resume!(client_id, now: Time.current)
    if running?
      raise Conflict, "run #{key} is held by another client" if lease_owner != client_id && !lease_expired?(now)
    elsif REOPENABLE.include?(status) && started_at > now - REOPEN_WINDOW
      if self.class.where(kind: kind, status: "running").where.not(id: id).exists?
        raise Conflict, "another #{kind.humanize(capitalize: false)} run is in progress"
      end

      self.status = "running"
      self.finished_at = nil
    else
      raise Conflict, "run #{key} is already #{status}"
    end
    update!(lease_owner: client_id, last_activity_at: now)
    self
  end

  def running?
    status == "running"
  end

  def lease_expired?(now = Time.current)
    last_activity_at.nil? || last_activity_at < now - LEASE
  end

  def held_by?(client_id, now: Time.current)
    running? && (lease_owner == client_id || lease_expired?(now))
  end

  def renew!(client_id, now: Time.current)
    update_columns(lease_owner: client_id, last_activity_at: now, updated_at: now)
  end

  def log_error!(message, **context)
    self.error_log = error_log + [ { "at" => Time.current.iso8601, "message" => message }.merge(context.stringify_keys) ]
    save!
  end

  # Ends the run. "completed" only counts when every target was scanned.
  def finish!(status, targeted: nil, notes: nil)
    status = "partial" if status == "completed" && targeted && market_snapshots.count < targeted
    update!(status: status, finished_at: Time.current, notes: [ self.notes, notes ].compact_blank.join("\n").presence,
            stats: stats.merge("targeted" => targeted, "scanned" => market_snapshots.count).compact)
  end
end
