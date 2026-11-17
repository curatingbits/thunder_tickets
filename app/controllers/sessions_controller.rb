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
      # Shown in the line under the password, which is always there, so the
      # page doesn't move.
      @login_error = "Wrong email or password. Try again."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Logged out successfully"
  end
end
