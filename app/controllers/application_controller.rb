class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_user, :logged_in?

  private

  # Re-checked on every request, so deactivating someone ends any session
  # they already have open rather than waiting for them to log out. The
  # token itself runs out a year after sign-in (User's :login token).
  def current_user
    @current_user ||= User.active.find_by_token_for(:login, session[:login_token]) if session[:login_token]
  end

  def log_in(user)
    reset_session
    session[:login_token] = user.generate_token_for(:login)
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
  # season, but a ?season_id= anywhere sticks until the browser or the
  # home-screen app closes, so switching on the dashboard carries over to
  # Games and back. It's kept in its own cookie because the session cookie
  # lasts a year.
  #
  # Distinct from current_season, which is the is_current flag and stays the
  # anchor for "what season are we actually in".
  def viewed_season
    return @viewed_season if defined?(@viewed_season)

    @viewed_season =
      if params[:season_id].present? && (season = Season.find_by(id: params[:season_id]))
        cookies[:viewed_season_id] = { value: season.id, httponly: true }
        season
      elsif cookies[:viewed_season_id] && (season = Season.find_by(id: cookies[:viewed_season_id]))
        season
      else
        cookies.delete(:viewed_season_id)
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
