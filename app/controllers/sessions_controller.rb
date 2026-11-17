class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]

  def new
  end

  def create
    # Deactivated accounts get the same "invalid" response as a wrong
    # password, so the form doesn't confirm which emails exist.
    user = User.active.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      log_in(user)
      redirect_to root_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Logged out successfully"
  end
end
