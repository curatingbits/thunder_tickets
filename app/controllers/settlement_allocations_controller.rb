# Undoing an allocation keeps the record (voided, with a reason) so the
# history of every correction survives.
class SettlementAllocationsController < ApplicationController
  def void
    allocation = SettlementAllocation.find(params[:id])
    Settlements::Allocator.void!(allocation, reason: params[:reason], user: current_user)
    redirect_to allocation.partner_payment, notice: "Allocation voided."
  rescue Settlements::Allocator::Error => e
    redirect_to allocation.partner_payment, alert: e.message
  end
end
