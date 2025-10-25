class InvitationsController < ApplicationController
  skip_before_action :require_login

  def show
    @user = User.find_by_invitation_token(params[:token])

    if @user.nil?
      redirect_to login_path, alert: "Invalid or expired invitation link."
    elsif @user.invitation_accepted?
      redirect_to login_path, notice: "This invitation has already been accepted. Please login."
    end
  end

  def update
    @user = User.find_by_invitation_token(params[:token])

    if @user.nil?
      redirect_to login_path, alert: "Invalid or expired invitation link."
      return
    end

    if @user.accept_invitation!(
      params[:user][:password],
      params[:user][:password_confirmation]
    )
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to ThunderTickets! Your account has been activated."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
