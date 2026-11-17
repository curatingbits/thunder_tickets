module Market
  # Which of the three prices to recommend, and why. Close to the game,
  # sell; far out with a rising market, ask more; when the data is thin,
  # stay at market.
  module Strategy
    module_function

    def choose(days:, change_pct:, supply_change_pct:, confidence:)
      change = change_pct || 0
      supply = supply_change_pct || 0

      if confidence < 25
        [ "market", "too little data to push the price either way" ]
      elsif days <= 3
        [ "competitive", "#{days.zero? ? "game day" : "#{days} day#{'s' unless days == 1} out"}: price to sell" ]
      elsif days <= 7
        if change >= 10 && supply <= 0
          [ "market", "a week out, but the market is up #{change.round}% and supply isn't growing" ]
        else
          [ "competitive", "#{days} days out: price to sell" ]
        end
      elsif days <= 21
        if change <= -10 || supply >= 25
          [ "competitive", change <= -10 ? "market down #{change.abs.round}% since last week" : "listings up #{supply.round}% since last week" ]
        elsif change >= 10 && confidence >= 40
          [ "premium", "market up #{change.round}% since last week" ]
        else
          [ "market", "#{days} days out, market steady" ]
        end
      elsif change <= -10 || confidence < 40
        [ "market", change <= -10 ? "market down #{change.abs.round}% since last week" : "plenty of time, but the data is thin" ]
      else
        [ "premium", "#{days} days out: time to ask more" ]
      end
    end
  end
end
