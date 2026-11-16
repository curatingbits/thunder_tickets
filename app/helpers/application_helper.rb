module ApplicationHelper
  # Profit/loss with an explicit sign: "+$1,234", "-$390", "$0".
  #
  # Rounds to whole dollars like the rest of the summary figures, and takes
  # the sign from the rounded value so a $0.40 loss reads "$0", not "-$0".
  # Replaces hand-built "+$<n>" strings, which rendered losses as "$-390"
  # and, where the "+" was hardcoded, "+$-70".
  def signed_currency(amount, precision: 0)
    rounded = amount.round(precision)
    formatted = number_to_currency(rounded.abs, precision: precision)

    if rounded.positive?
      "+#{formatted}"
    elsif rounded.negative?
      "-#{formatted}"
    else
      formatted
    end
  end
end
