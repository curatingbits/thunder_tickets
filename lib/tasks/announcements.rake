namespace :announcements do
  desc "Email the 2026-11-17 what's-new tour. TO and FROM are active users' emails; FROM is copied " \
       "and gets the replies. Shows the email and sends nothing unless SEND=yes."
  task whats_new: :environment do
    recipient, sender = %w[TO FROM].map do |key|
      email = ENV[key].to_s.strip
      User.active.find_by(email: email) || abort("#{key} must be an active user's email (got #{email.inspect}).")
    end

    message = AnnouncementMailer.with(recipient:, sender:).whats_new
    puts message.subject
    %i[from to cc reply_to].each { |field| puts format("  %-9s %s", "#{field.to_s.dasherize}:", message[field]) }

    if ENV["SEND"] == "yes"
      message.deliver_now
      puts "Sent (id #{message.message_id})."
    else
      puts "Dry run: nothing sent. Add SEND=yes to send it."
    end
  end
end
