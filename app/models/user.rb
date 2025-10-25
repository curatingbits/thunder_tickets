class User < ApplicationRecord
  has_secure_password validations: false

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :pending_invitation, -> { where.not(invitation_token: nil).where(invitation_accepted_at: nil) }
  scope :accepted, -> { where.not(invitation_accepted_at: nil) }

  before_create :set_reset_token

  # Password Reset Methods
  def self.find_by_reset_token(token)
    where("reset_password_sent_at > ?", 2.hours.ago).find_by(reset_password_token: token)
  end

  def generate_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!
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

  private

  def set_reset_token
    self.reset_password_token = SecureRandom.urlsafe_base64
  end

  def password_required?
    invitation_accepted_at.present? || (!invitation_pending? && new_record?)
  end
end
