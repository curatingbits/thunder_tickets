module Settlements
  # Brings in payments read from the finance app. Idempotent by the source's
  # transaction id; a transaction that comes back different is flagged for
  # review, never overwritten. Pending transactions are skipped (the finance
  # app replaces them when they post). Then the matcher runs.
  class Importer
    Summary = Data.define(:received, :created, :unchanged, :changed, :skipped_pending, :duplicates, :missing, :matched, :review, :ignored, :waiting)

    def initialize(run:, transactions:, source: "finance_api", window: nil, complete: false, api_token: nil)
      @run = run
      @transactions = Array(transactions)
      @source = source
      @window = window
      @complete = complete
      @api_token = api_token
      @partner = Settlements.partner_name
    end

    def call
      counts = Hash.new(0)
      seen = []
      PartnerPayment.transaction do
        @transactions.each do |tx|
          tx = tx.to_h.stringify_keys
          next counts[:skipped_pending] += 1 if ActiveModel::Type::Boolean.new.cast(tx["pending"])

          id = tx["id"].to_s.presence or raise ArgumentError, "a transaction has no id"
          seen << id
          outcome = upsert(id, tx)
          counts[outcome] += 1
        end
        counts[:missing] = flag_missing(seen) if @complete && @window
      end
      outcomes = Matcher.new.run.tally
      Summary.new(received: @transactions.size, created: counts[:created], unchanged: counts[:unchanged], changed: counts[:changed],
                  skipped_pending: counts[:skipped_pending], duplicates: counts[:duplicate], missing: counts[:missing],
                  matched: outcomes[:auto].to_i, review: outcomes[:review].to_i, ignored: outcomes[:ignored].to_i,
                  waiting: outcomes[:waiting].to_i)
    end

    private

    def upsert(id, tx)
      date = Date.iso8601(tx.fetch("date").to_s)
      amount = BigDecimal(tx.fetch("amount").to_s)
      raise ArgumentError, "transaction #{id} has a zero amount" if amount.zero?

      cents = (amount.abs * 100).round.to_i
      direction = amount.positive? ? "incoming" : "outgoing"
      existing = PartnerPayment.find_by(source: @source, external_id: id)
      if existing
        same = existing.occurred_on == date && existing.amount_cents == cents && existing.direction == direction
        return :unchanged if same

        existing.update!(status: "needs_review", review_note: "changed at the source: now #{date} #{direction} #{cents / 100.0}")
        Allocator.audit(existing, "source_changed", { date: date, cents: cents, direction: direction }, nil, nil, @api_token)
        return :changed
      end

      name = tx["name"].to_s
      parsed = MemoParser.parse(name)
      payment = PartnerPayment.create!(
        import_run: @run, source: @source, external_id: id, occurred_on: date, amount_cents: cents, direction: direction,
        counterparty: parsed.payer, memo: parsed.memo, raw_name: name.first(500), account_name: tx["account"].to_s.first(100),
        raw: tx.slice("id", "plaid_transaction_id", "date", "amount", "name", "account")
      )
      if (twin = duplicate_of(payment))
        payment.update!(possible_duplicate_of: twin)
        return :duplicate
      end
      :created
    end

    # Same day, amount, direction and memo under a different id.
    def duplicate_of(payment)
      PartnerPayment.where(occurred_on: payment.occurred_on, amount_cents: payment.amount_cents, direction: payment.direction)
                    .where.not(id: payment.id).find { |other| other.memo.to_s.squish == payment.memo.to_s.squish }
    end

    # Payments we hold for the window that the source no longer returns.
    def flag_missing(seen)
      from = Date.iso8601(@window["from"].to_s)
      to = Date.iso8601(@window["to"].to_s)
      gone = PartnerPayment.where(source: @source, occurred_on: from..to, source_missing_at: nil).where.not(external_id: seen)
      gone.find_each do |payment|
        payment.update!(source_missing_at: Time.current)
        payment.update!(status: "needs_review", review_note: "no longer in the finance app") if payment.allocations.active.any?
      end
      gone.count
    end
  end
end
