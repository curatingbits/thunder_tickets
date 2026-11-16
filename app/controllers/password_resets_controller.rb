class PasswordResetsController < ApplicationController
  skip_before_action :require_login
  before_action :set_user_from_token, only: [ :edit, :update ]

  def new
  end

  def create
    # Only active accounts can reset. Deactivated users are locked out on
    # purpose, and pending invitees should use their invitation link instead.
    user = User.active.find_by(email: params[:email].to_s.strip.downcase)

    if user
      user.generate_reset_token!
      UserMailer.with(user: user, token: user.reset_password_token).password_reset.deliver_later
    end

    # Same response either way, so this form can't be used to discover which
    # email addresses have accounts.
    redirect_to login_path, notice: "If that email has an account, a reset link is on its way. It expires in #{User::RESET_TOKEN_TTL.inspect}."
  end

  def edit
  end

  def update
    if @user.reset_password(params[:password], params[:password_confirmation])
      redirect_to login_path, notice: "Password reset. Log in with your new password."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_from_token
    @user = User.active.find_by_reset_token(params[:id])
    redirect_to login_path, alert: "That reset link is invalid or has expired." unless @user
  end
end
