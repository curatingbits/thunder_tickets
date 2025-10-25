class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_create :set_reset_token

  def self.find_by_reset_token(token)
    where("reset_password_sent_at > ?", 2.hours.ago).find_by(reset_password_token: token)
  end

  def generate_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!
  end

  private

  def set_reset_token
    self.reset_password_token = SecureRandom.urlsafe_base64
  end
end
