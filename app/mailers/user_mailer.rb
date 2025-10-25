class UserMailer < ApplicationMailer
  def invitation_email
    @user = params[:user]
    @invitation_url = params[:invitation_url]
    @expires_at = @user.invitation_sent_at + 7.days

    mail(
      to: @user.email,
      subject: "You've been invited to Thunder Tickets"
    )
  end
end
