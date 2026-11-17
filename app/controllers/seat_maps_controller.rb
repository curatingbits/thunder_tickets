# The 3D seat map: sections 119, 120, 101 and 102 with every listing the
# research read for one game, and the list beside it. A game's 3D button on
# Pricing opens it here. Choosing another game swaps only the frame, so the
# 3D view carries on with the new game's data.
class SeatMapsController < ApplicationController
  FRAME = "seat_map_game"

  def show
    @season = current_season
    return redirect_to root_path, alert: "No current season" unless @season

    board = Market::Board.new(@season)
    rows = board.rows.select(&:snapshot)
    @games = rows.map(&:game)
    if (row = rows.find { |r| r.game.id == params[:game_id].to_i } || rows.first)
      @game = row.game
      @seat_map = Market::SeatMap.new(row.snapshot, settings: board.settings, our_all_in: row.our_all_in)
    end
    render partial: "seat_maps/frame" if turbo_frame_request_id == FRAME
  end
end
