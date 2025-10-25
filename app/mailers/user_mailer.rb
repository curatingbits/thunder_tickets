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

  def daily_digest
    @user = params[:user]
    @games = Game.upcoming.limit(3)

    mail(
      to: @user.email,
      subject: "Your Daily MADR TICKETS Digest - #{Date.current.strftime("%B %d, %Y")}"
    )
  end
end
