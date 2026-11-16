class UserMailer < ApplicationMailer
  def invitation_email
    @user = params[:user]
    @invitation_url = params[:invitation_url]
    @expires_at = @user.invitation_sent_at + 7.days

    mail(
      to: @user.email,
      subject: "You've been invited to MADR TICKETS"
    )
  end

  def password_reset
    @user = params[:user]
    @reset_url = edit_password_reset_url(params[:token])
    @expires_in = User::RESET_TOKEN_TTL.inspect

    mail(
      to: @user.email,
      subject: "Reset your MADR TICKETS password"
    )
  end

  def daily_digest
    @user = params[:user]
    @games = Game.upcoming.limit(3)

    mail(
      to: @user.email,
      subject: "Your Daily MADR TICKETS Digest - #{Date.current.strftime("%B %d, %Y")}"
    )
  end
end
