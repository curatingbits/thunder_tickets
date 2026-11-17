# News about the app, written by Duggan and sent through it.
class AnnouncementMailer < ApplicationMailer
  # The email is a whole page of its own, styled for mail apps.
  layout false

  # The tour of what shipped on 2026-11-17: sent to the recipient, copying the
  # sender, who gets the replies. Its screenshots are served from public/emails.
  def whats_new
    recipient = params[:recipient]
    sender = params[:sender]
    @images = "#{root_url}emails/whats-new-2026-11-17"

    mail(
      from: email_address_with_name(default_params[:from], "MADR Tickets"),
      to: email_address_with_name(recipient.email, recipient.name),
      cc: email_address_with_name(sender.email, sender.name),
      reply_to: email_address_with_name(sender.email, sender.name),
      subject: "Six new things in MADR Tickets",
      # Resend sends a repeated request with the same key (within a day) only once.
      options: { idempotency_key: "whats-new-2026-11-17/#{recipient.id}" }
    )
  end
end
