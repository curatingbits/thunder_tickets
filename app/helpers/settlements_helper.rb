module SettlementsHelper
  BALANCE_CHIPS = {
    paid: [ "Paid", :positive ], partially_paid: [ "Partly paid", :warning ],
    unpaid: [ "Unpaid", :warning ], needs_review: [ "Needs review", :alt ]
  }.freeze

  PAYMENT_CHIPS = {
    "matched" => [ "Settled", :positive ], "partially_matched" => [ "Partly settled", :warning ],
    "needs_review" => [ "Needs review", :alt ], "unmatched" => [ "Not matched yet", :neutral ], "ignored" => [ "Ignored", :neutral ]
  }.freeze

  def balance_chip(status)
    label, tone = BALANCE_CHIPS.fetch(status)
    status_chip(label, tone: tone, data: { settlement_status: status })
  end

  def payment_chip(payment)
    label, tone = PAYMENT_CHIPS.fetch(payment.status)
    status_chip(label, tone: tone, data: { payment_status: payment.status })
  end

  def cents(amount_cents, signed: false)
    text = number_to_currency(amount_cents.abs / 100.0)
    signed && amount_cents.negative? ? "-#{text}" : text
  end

  # "Mark owes Duggan $263.63" / "Duggan owes Mark $20.00" / "All square".
  def owes_sentence(outstanding_cents)
    partner = Settlements.partner_first_name
    owner = Settlements.owner_name
    if outstanding_cents.abs <= 1 then "All square"
    elsif outstanding_cents.positive? then "#{partner} owes #{owner} #{cents(outstanding_cents)}"
    else "#{owner} owes #{partner} #{cents(outstanding_cents)}"
    end
  end

  def payment_direction(payment)
    partner = Settlements.partner_first_name
    owner = Settlements.owner_name
    payment.incoming? ? "#{partner} → #{owner}" : "#{owner} → #{partner}"
  end
end
