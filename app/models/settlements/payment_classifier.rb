module Settlements
  # What a payment is about, before matching:
  #   settlement  ticket money (Thunder, ⚡, a team or a game date in the memo)
  #   cost_share  Duggan's installments on the season invoice ("26/27",
  #               "2026-2027", "season", "installment")
  #   unrelated   everything else between friends (⛳, 🥃, dinner)
  #   unknown     an incoming payment with no ticket words; it's ignored only
  #               if its amount doesn't equal what a game owes
  module PaymentClassifier
    module_function

    def call(payment, parsed)
      text = parsed.memo.to_s.downcase
      ticket_words = parsed.thunder || parsed.any_reference?
      if payment.direction == "outgoing"
        return "cost_share" if season_token?(text) || text.match?(/\b(?:season|installment|10%)/)

        ticket_words ? "settlement" : "unrelated"
      else
        ticket_words ? "settlement" : "unknown"
      end
    end

    def season_token?(text) = !season_start_year(text).nil?

    # "26/27", "2026/2027" or "2026-2027" -> 2026: consecutive years. A month
    # can't be 13+, so a game date like "10/11" never looks like a season.
    def season_start_year(text)
      text.to_s.scan(%r{\b(\d{2})\s*/\s*(\d{2})\b}).each { |a, b| return 2000 + a.to_i if a.to_i >= 13 && b.to_i == a.to_i + 1 }
      text.to_s.scan(%r{\b(20\d{2})\s*[/-]\s*(20\d{2})\b}).each { |a, b| return a.to_i if b.to_i == a.to_i + 1 }
      nil
    end
  end
end
