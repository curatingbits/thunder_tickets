# The weekly listing checklist: every upcoming game with seats to sell, its
# listing status, and one-tap confirmations.
class ListingReviewsController < ApplicationController
  def show
    @season = current_season
    games = @season ? @season.games.upcoming.includes(:opponent, :tickets, :listings, :listing_events) : []
    @rows = games.filter_map do |game|
      status = game.listing_status
      [ game, status ] if status.open_seats.any?
    end
  end
end
