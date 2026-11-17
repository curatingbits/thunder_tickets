module AttentionHelper
  def attention_path(item)
    case item.kind
    when :verify_listing then listing_review_path
    when :research_blocked then import_runs_path
    when :research_stale then pricing_path
    when :settlement_review then partner_payments_path(filter: "review")
    when :payout_overdue then money_path
    else game_path(item.game)
    end
  end

  def attention_title(item)
    vs = item.game && "vs #{item.game.opponent.name}"
    case item.kind
    when :research_blocked then "Ticketmaster research was blocked"
    when :research_stale then "Market data is over #{(Attention::Feed::STALE_RESEARCH / 1.day).to_i} days old"
    when :settlement_review then "#{pluralize(item.assessment, "Venmo payment")} to review"
    when :payout_overdue
      owed = item.assessment.sum(&:outstanding_cents)
      "#{Settlements.partner_first_name} owes #{number_to_currency(owed / 100.0)} for #{pluralize(item.assessment.size, "game")}"
    when :transfer_pending then "Deliver #{pluralize(item.status.untransferred_count, "ticket")} #{vs}"
    when :unsold_soon then "#{pluralize(item.seats_open, "seat")} to sell #{vs}"
    when :reprice then "#{item.assessment == "overpriced" ? "Priced above" : "Priced below"} market #{vs}"
    when :market_drop then "Market down #{item.snapshot.market_value_change_pct.abs.round}% #{vs}"
    when :not_listed then "List #{pluralize(item.seats_open, "seat")} #{vs}"
    when :verify_listing then "Confirm the listing #{vs}"
    end
  end

  def attention_detail(item)
    case item.kind
    when :research_blocked then "Partial results are saved. Run it again later, or add listings by hand."
    when :research_stale then "Recommendations are getting old. Run the research or add listings by hand."
    when :settlement_review then "The matcher wasn't sure which games these settle."
    when :payout_overdue
      "Sold over two weeks ago: " + item.assessment.map { |b| "#{b.game.opponent.name} #{b.game.game_date.strftime('%-m/%-d')}" }.to_sentence
    else
      extra =
        case item.kind
        when :transfer_pending then "sold, not marked delivered"
        when :unsold_soon
          if item.snapshot&.recommended_list_price
            safe_join([ "list at ", tag.span(dollars(item.snapshot.recommended_list_price), class: "text-content figure") ])
          elsif (price = item.game.break_even_price_for_remaining)
            safe_join([ "break even at ", tag.span("$#{number_with_delimiter(price.round)}", class: "text-content figure"), " each" ])
          end
        when :reprice, :market_drop
          safe_join([ "market ", tag.span(dollars(item.snapshot.market_value), class: "text-content figure"),
                      " all-in, list at ", tag.span(dollars(item.snapshot.recommended_list_price), class: "text-content figure") ])
        else listing_status_detail(item.status)
        end
      safe_join([ game_when(item.game), extra ].compact, " · ")
    end
  end
end
