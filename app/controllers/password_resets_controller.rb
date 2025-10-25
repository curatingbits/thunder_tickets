class PasswordResetsController < ApplicationController
  skip_before_action :require_login

  def new
  end

  def create
    user = User.find_by(email: params[:email].downcase)

    if user
      user.generate_reset_token!
      # In a real app, send email here
      flash[:notice] = "Password reset instructions sent (check console for token)"
      puts "\n=== PASSWORD RESET TOKEN ==="
      puts "Email: #{user.email}"
      puts "Reset URL: http://localhost:3000/password_resets/#{user.reset_password_token}/edit"
      puts "===========================\n"
    else
      flash[:notice] = "If that email exists, password reset instructions have been sent"
    end

    redirect_to login_path
  end

  def edit
    @user = User.find_by_reset_token(params[:id])

    unless @user
      flash[:alert] = "Invalid or expired password reset link"
      redirect_to login_path
    end
  end

  def update
    @user = User.find_by_reset_token(params[:id])

    unless @user
      flash[:alert] = "Invalid or expired password reset link"
      redirect_to login_path
      return
    end

    if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      @user.update(reset_password_token: nil, reset_password_sent_at: nil)
      flash[:notice] = "Password reset successfully"
      redirect_to login_path
    else
      flash.now[:alert] = "Passwords don't match or are invalid"
      render :edit, status: :unprocessable_entity
    end
  end
end
