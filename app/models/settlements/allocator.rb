module Settlements
  # The only way allocations are made or undone. Keeps a payment from being
  # spent twice, keeps its status right, and audits every change.
  module Allocator
    class Error < StandardError; end

    module_function

    def allocate!(payment, game, cents, method:, reason:, confidence: nil, user: nil, api_token: nil, replaces: nil)
      cents = Integer(cents)
      raise Error, "amount must be positive" unless cents.positive?

      PartnerPayment.transaction do
        payment.lock!
        payment.reload
        if cents > payment.unallocated_cents
          raise Error, "only #{format_cents(payment.unallocated_cents)} of this payment is left to allocate"
        end

        allocation = payment.allocations.create!(game: game, amount_cents: payment.incoming? ? cents : -cents,
                                                 method: method, reason: reason, confidence: confidence,
                                                 created_by: user, replaces: replaces)
        payment.update!(status: "unmatched") if payment.status.in?(%w[needs_review ignored])
        payment.reload.refresh_status!
        audit(payment, "allocated", { game_id: game.id, cents: allocation.amount_cents, method: method }, reason, user, api_token)
        allocation
      end
    end

    def void!(allocation, reason:, user: nil)
      raise Error, "a reason is required" if reason.blank?
      raise Error, "already voided" unless allocation.active?

      PartnerPayment.transaction do
        allocation.update!(voided_at: Time.current, voided_by: user, void_reason: reason)
        payment = allocation.partner_payment
        payment.reload.refresh_status!
        audit(payment, "voided", { allocation_id: allocation.id, game_id: allocation.game_id, cents: allocation.amount_cents },
              reason, user, nil)
      end
    end

    def set_status!(payment, status, note:, user: nil, category: nil)
      PartnerPayment.transaction do
        before = payment.slice(:status, :category)
        payment.update!(status: status, category: category || payment.category, review_note: note,
                        reviewed_by: user, reviewed_at: Time.current)
        audit(payment, "status", { from: before, to: payment.slice(:status, :category) }, note, user, nil)
      end
    end

    def audit(payment, action, changeset, note, user, api_token)
      AuditEvent.create!(auditable: payment, action: action, changeset: changeset, note: note, user: user, api_token: api_token)
    end

    def format_cents(cents)
      ActiveSupport::NumberHelper.number_to_currency(cents / 100.0)
    end
  end
end
