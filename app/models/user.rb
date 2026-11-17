class User < ApplicationRecord
  has_secure_password validations: false

  # What the session keeps for a login. It ends a year after sign-in, and a
  # password reset ends every login made with the old password.
  generates_token_for :login, expires_in: Rails.configuration.x.login_lasts do
    password_salt&.last(10)
  end

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, presence: true, length: { minimum: 6 }, if: -> { password_required? || validation_context == :password_reset }
  # has_secure_password's own confirmation check is switched off above along
  # with the rest of its validations, so restore it explicitly. Only runs when
  # a confirmation is actually submitted.
  validates :password, confirmation: true

  RESET_TOKEN_TTL = 2.hours

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :pending_invitation, -> { where.not(invitation_token: nil).where(invitation_accepted_at: nil) }
  scope :accepted, -> { where.not(invitation_accepted_at: nil) }

  before_create :set_reset_token

  # Password Reset Methods
  def self.find_by_reset_token(token)
    return nil if token.blank?

    where("reset_password_sent_at > ?", RESET_TOKEN_TTL.ago).find_by(reset_password_token: token)
  end

  def generate_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!
  end

  # Sets a new password from a reset link and burns the token so the link
  # can't be replayed. A password is required here regardless of invitation
  # state — a blank reset is never valid.
  def reset_password(new_password, confirmation)
    self.password = new_password
    self.password_confirmation = confirmation
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save(context: :password_reset)
  end

  # Invitation Methods
  def generate_invitation_token!
    self.invitation_token = SecureRandom.urlsafe_base64(24)
    self.invitation_sent_at = Time.current
    self.invitation_accepted_at = nil
    save!(validate: false)
  end

  def self.find_by_invitation_token(token)
    where("invitation_sent_at > ?", 7.days.ago)
      .where(invitation_accepted_at: nil)
      .find_by(invitation_token: token)
  end

  def accept_invitation!(password, password_confirmation)
    self.password = password
    self.password_confirmation = password_confirmation
    self.invitation_accepted_at = Time.current
    self.invitation_token = nil
    self.active = true
    save
  end

  def invitation_pending?
    invitation_token.present? && invitation_accepted_at.nil?
  end

  def invitation_accepted?
    invitation_accepted_at.present?
  end

  def invitation_expired?
    invitation_sent_at.present? && invitation_sent_at < 7.days.ago && invitation_accepted_at.nil?
  end

  def deactivate!
    update(active: false)
  end

  def activate!
    update(active: true)
  end

  def status
    return "Inactive" unless active?
    return "Pending Invitation" if invitation_pending?
    return "Expired Invitation" if invitation_expired?
    "Active"
  end

  def status_badge_color
    case status
    when "Active" then "green"
    when "Pending Invitation" then "yellow"
    when "Expired Invitation" then "orange"
    when "Inactive" then "red"
    end
  end

  # Full literal class strings, not interpolated fragments: Tailwind scans
  # source for complete class names, so "bg-#{color}-900/50" is invisible to
  # it and silently renders unstyled in production. Keys are the status's
  # colour family; values use the semantic tokens.
  STATUS_BADGE_CLASSES = {
    "green" => "bg-positive/15 text-positive border border-positive/40",
    "yellow" => "bg-warning/15 text-warning border border-warning/40",
    "orange" => "bg-accent-alt/15 text-accent-alt border border-accent-alt/40",
    "red" => "bg-negative/15 text-negative border border-negative/40"
  }.freeze

  def status_badge_classes
    STATUS_BADGE_CLASSES.fetch(status_badge_color, STATUS_BADGE_CLASSES["red"])
  end

  private

  def set_reset_token
    self.reset_password_token = SecureRandom.urlsafe_base64
  end

  def password_required?
    invitation_accepted_at.present? || (!invitation_pending? && new_record?)
  end
end
