# Venmo payments between Duggan and Mark, and the review decisions on them.
# Every change goes through Settlements::Allocator, which audits it.
class PartnerPaymentsController < ApplicationController
  before_action :set_payment, only: [ :show, :apply_suggestion, :allocate, :ignore, :reopen ]

  FILTERS = { "review" => { status: "needs_review" }, "settled" => { status: %w[matched partially_matched] },
              "ignored" => { status: "ignored" }, "open" => { status: %w[unmatched needs_review partially_matched] } }.freeze

  def index
    @payments = PartnerPayment.recent_first.includes(allocations: { game: :opponent })
    @payments = @payments.where(FILTERS[params[:filter]]) if FILTERS.key?(params[:filter])
    @payments = @payments.limit(200)
  end

  def show
    @games = settleable_games
  end

  def new
    @payment = PartnerPayment.new(occurred_on: Date.current, direction: "incoming")
  end

  # A payment typed in by hand (one the finance app doesn't have).
  def create
    @payment = PartnerPayment.new(manual_params.merge(source: "manual", external_id: "manual-#{SecureRandom.uuid}",
                                                      counterparty: Settlements.partner_name))
    @payment.amount_cents = (BigDecimal(params.dig(:partner_payment, :amount).to_s) * 100).round.to_i
    @payment.raw_name = %(#{Settlements.partner_name} "#{@payment.memo}")
    if @payment.save
      Settlements::Allocator.audit(@payment, "created", { source: "manual" }, "entered by hand", current_user, nil)
      Settlements::Matcher.new.match(@payment)
      redirect_to @payment, notice: "Payment added."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ArgumentError
    @payment.errors.add(:base, "Amount must be a number")
    render :new, status: :unprocessable_entity
  end

  def apply_suggestion
    suggestion = Array(@payment.match_details["suggestion"])
    return redirect_to(@payment, alert: "No suggestion to apply.") if suggestion.empty?

    PartnerPayment.transaction do
      suggestion.each do |s|
        Settlements::Allocator.allocate!(@payment, Game.find(s["game_id"]), s["cents"].to_i.abs, method: "manual",
                                         reason: "suggestion applied by #{current_user.name}", user: current_user)
      end
    end
    redirect_to money_path, notice: "Payment settled."
  rescue Settlements::Allocator::Error => e
    redirect_to @payment, alert: e.message
  end

  def allocate
    game = settleable_games.find { |g| g.id == params[:game_id].to_i } or return redirect_to(@payment, alert: "Pick a game.")
    cents = (BigDecimal(params[:amount].to_s) * 100).round.to_i
    Settlements::Allocator.allocate!(@payment, game, cents, method: "manual", user: current_user,
                                     reason: params[:reason].presence || "allocated by #{current_user.name}")
    redirect_to @payment, notice: "Allocated #{helpers.number_to_currency(cents / 100.0)} to #{game.opponent.name}."
  rescue ArgumentError
    redirect_to @payment, alert: "Amount must be a number."
  rescue Settlements::Allocator::Error => e
    redirect_to @payment, alert: e.message
  end

  def ignore
    return redirect_to(@payment, alert: "Say why it's not a ticket payment.") if params[:note].blank?
    return redirect_to(@payment, alert: "Void its allocations first.") if @payment.allocations.active.any?

    Settlements::Allocator.set_status!(@payment, "ignored", note: params[:note], user: current_user,
                                       category: params[:category].presence_in(%w[unrelated cost_share]) || "unrelated")
    redirect_to money_path, notice: "Payment ignored."
  end

  # Back into the queue for another look (and another matcher pass).
  def reopen
    Settlements::Allocator.set_status!(@payment, "unmatched", note: "reopened by #{current_user.name}", user: current_user,
                                       category: @payment.category == "unrelated" ? "unknown" : @payment.category)
    Settlements::Matcher.new.match(@payment.reload)
    redirect_to @payment, notice: "Reopened."
  end

  private

  def set_payment
    @payment = PartnerPayment.find(params[:id])
  end

  def settleable_games
    Settlements::Ledger.new.balances.map(&:game)
  end

  def manual_params
    params.require(:partner_payment).permit(:occurred_on, :direction, :memo)
  end
end
