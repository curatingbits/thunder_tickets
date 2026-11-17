# Who changed what in the money records, and why. Append-only.
class AuditEvent < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :user, optional: true
  belongs_to :api_token, optional: true

  validates :action, presence: true

  def readonly?
    persisted?
  end
end
