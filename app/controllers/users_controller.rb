class UsersController < ApplicationController
  before_action :require_login
  before_action :set_user, only: [:edit, :update, :destroy, :toggle_active]

  def index
    @users = User.all.order(created_at: :desc)

    # Apply filters
    case params[:filter]
    when "active"
      @users = @users.active
    when "inactive"
      @users = @users.inactive
    when "pending"
      @users = @users.pending_invitation
    when "accepted"
      @users = @users.accepted
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.password = SecureRandom.urlsafe_base64(16) # Temporary password
    @user.active = false # User starts inactive until they accept invitation

    if @user.save(validate: false) # Skip validations since user hasn't set password yet
      @user.generate_invitation_token!

      # Send invitation email
      invitation_url = accept_invitation_url(token: @user.invitation_token)
      UserMailer.with(user: @user, invitation_url: invitation_url).invitation_email.deliver_later

      redirect_to users_path, notice: "Invitation email sent to #{@user.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "User updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user.deactivate!
      redirect_to users_path, notice: "User deactivated successfully."
    else
      redirect_to users_path, alert: "Failed to deactivate user."
    end
  end

  def toggle_active
    if @user.active?
      @user.deactivate!
      redirect_to users_path, notice: "User deactivated successfully."
    else
      @user.activate!
      redirect_to users_path, notice: "User activated successfully."
    end
  end

  def invitation_url
    @user = User.find(params[:id])
    @invitation_url = accept_invitation_url(token: @user.invitation_token)
    render json: { url: @invitation_url }
  end

  def resend_invitation
    @user = User.find(params[:id])

    if @user.invitation_pending?
      # Regenerate token and update sent time
      @user.generate_invitation_token!

      # Send invitation email
      invitation_url = accept_invitation_url(token: @user.invitation_token)
      UserMailer.with(user: @user, invitation_url: invitation_url).invitation_email.deliver_later

      redirect_to users_path, notice: "Invitation email resent to #{@user.email}."
    else
      redirect_to users_path, alert: "Cannot resend invitation to this user."
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
