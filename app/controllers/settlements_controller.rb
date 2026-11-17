# The Money tab: what Mark owes Duggan, game by game, and the payments that
# need a person's eye. Read-only toward Venmo and the bank: nothing here
# moves money.
class SettlementsController < ApplicationController
  def show
    @summary = Settlements::Summary.new
    @recent = PartnerPayment.recent_first.where.not(status: "ignored").includes(allocations: { game: :opponent }).limit(8)
  end
end
