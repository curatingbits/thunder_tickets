class SeasonsController < ApplicationController
  before_action :require_login

  def edit
    @season = Season.find_by(is_current: true)
    redirect_to root_path, alert: "No current season found" unless @season
  end

  def update
    @season = Season.find_by(is_current: true)

    if @season.update(season_params)
      redirect_to settings_path, notice: "Settings updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def season_params
    params.require(:season).permit(:seat_section)
  end
end
