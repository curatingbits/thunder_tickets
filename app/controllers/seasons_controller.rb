class SeasonsController < ApplicationController
  before_action :require_login

  def index
    @seasons = Season.order(year: :desc)
  end

  def edit
    @season = Season.find_by(is_current: true)
    return redirect_to root_path, alert: "No current season found" unless @season

    load_settings
  end

  def update
    @season = Season.find_by(is_current: true)

    if @season.update(season_params)
      redirect_to settings_path, notice: "Settings updated successfully."
    else
      load_settings
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_settings
    @tokens = ApiToken.order(revoked_at: :desc, created_at: :desc)
  end

  def season_params
    params.require(:season).permit(:seat_section, :seat_row)
  end
end
