# Bearer token for the workstation skills. Only a SHA-256 digest is stored;
# the token is shown once, when it's created (bin/rails api_tokens:create).
class ApiToken < ApplicationRecord
  SCOPES = %w[market:write settlements:write read].freeze
  PREFIX = "madr_".freeze

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validate :known_scopes

  scope :usable, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # Returns [token, raw]. Only the raw value can authenticate; keep it secret.
  def self.generate!(name:, scopes:, created_by: nil, expires_at: nil)
    raw = PREFIX + SecureRandom.base58(40)
    token = create!(name: name, scopes: Array(scopes).join(" "), token_digest: digest(raw),
                    token_prefix: raw.first(PREFIX.size + 6), created_by: created_by, expires_at: expires_at)
    [ token, raw ]
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def self.authenticate(raw)
    return if raw.blank?

    usable.find_by(token_digest: digest(raw))&.tap(&:touch_last_used)
  end

  def scope_list
    scopes.split
  end

  def allows?(scope)
    scope_list.include?(scope)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # At most once a minute, so a busy run doesn't write on every request.
  def touch_last_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end

  private

  def known_scopes
    unknown = scope_list - SCOPES
    errors.add(:scopes, "unknown: #{unknown.join(', ')}") if unknown.any?
    errors.add(:scopes, "can't be empty") if scope_list.empty?
  end
end
