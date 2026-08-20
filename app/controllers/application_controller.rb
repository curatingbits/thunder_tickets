class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      flash[:alert] = "You must be logged in to access this page"
      redirect_to login_path
    end
  end

  def current_season
    @current_season ||= Season.find_by(is_current: true)
  end
  helper_method :current_season

  # The season the user is currently looking at. Defaults to the current
  # season, but a ?season_id= anywhere sticks for the rest of the session so
  # switching on the dashboard carries over to Games and back.
  #
  # Distinct from current_season, which is the is_current flag and stays the
  # anchor for "what season are we actually in".
  def viewed_season
    return @viewed_season if defined?(@viewed_season)

    @viewed_season =
      if params[:season_id].present? && (season = Season.find_by(id: params[:season_id]))
        session[:viewed_season_id] = season.id
        season
      elsif session[:viewed_season_id] && (season = Season.find_by(id: session[:viewed_season_id]))
        season
      else
        session.delete(:viewed_season_id)
        current_season
      end
  end
  helper_method :viewed_season

  def viewing_current_season?
    viewed_season.present? && viewed_season == current_season
  end
  helper_method :viewing_current_season?

  # Carries the viewed season through links when it isn't the current one, so
  # nav doesn't silently snap the user back to this year.
  def season_scope_params
    viewing_current_season? || viewed_season.nil? ? {} : { season_id: viewed_season.id }
  end
  helper_method :season_scope_params
end
