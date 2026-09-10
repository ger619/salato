# Diagnostics for outbound email.
#
#   bin/rails "mail:config"
#   bin/rails "mail:test[you@example.com]"
#
# In development, delivery is written to tmp/mails unless SEND_REAL_EMAIL
# is set, so to actually put a message on the wire use:
#
#   SEND_REAL_EMAIL=1 bin/rails "mail:test[you@example.com]"
#
namespace :mail do
  desc 'Print the active Action Mailer delivery settings'
  task config: :environment do
    settings = ActionMailer::Base.smtp_settings || {}

    puts "environment      : #{Rails.env}"
    puts "delivery_method  : #{ActionMailer::Base.delivery_method}"
    puts "perform_deliveries: #{ActionMailer::Base.perform_deliveries}"
    puts "raise_errors     : #{ActionMailer::Base.raise_delivery_errors}"
    puts "default from     : #{ApplicationMailer.default[:from]}"
    puts "url host         : #{Rails.application.config.action_mailer.default_url_options.inspect}"

    next unless ActionMailer::Base.delivery_method == :smtp

    puts "smtp address     : #{settings[:address]}:#{settings[:port]}"
    puts "smtp user_name   : #{settings[:user_name].inspect}"
    puts "smtp password    : #{settings[:password].present? ? 'set' : 'MISSING'}"

    resend = settings[:address].to_s.include?('resend')
    warn "\nWARNING: RESEND_API_KEY is not set." if resend && settings[:password].blank?

    next unless resend && settings[:user_name] != 'resend'

    warn "\nWARNING: Resend expects the SMTP username to be the literal " \
         'string "resend", not an email address. Authentication will fail.'
  end

  desc 'Send a test email. Usage: bin/rails "mail:test[you@example.com]"'
  task :test, [:to] => :environment do |_task, args|
    to = args[:to].presence || ENV.fetch('TO', nil)
    abort 'Usage: bin/rails "mail:test[you@example.com]"' if to.blank?

    from = ApplicationMailer.default[:from]
    puts "Sending via #{ActionMailer::Base.delivery_method} from #{from} to #{to} ..."

    ActionMailer::Base.mail(
      from: from,
      to: to,
      subject: "Salato mail test — #{Time.current.strftime('%d %b %Y %H:%M')}",
      body: <<~BODY
        This is a test message from the Salato app.

        Environment     : #{Rails.env}
        Delivery method : #{ActionMailer::Base.delivery_method}
        Sent at         : #{Time.current}

        If you are reading this in an inbox, outbound email is working.
      BODY
    ).deliver_now

    if ActionMailer::Base.delivery_method == :file
      puts "Written to #{Rails.root.join('tmp/mails')} (not actually sent)."
      puts 'Re-run with SEND_REAL_EMAIL=1 to deliver through Resend.'
    else
      puts 'Accepted by the mail server. Check the Resend dashboard for delivery status.'
    end
  end

  desc 'Render the Devise invitation email. Saves nothing and sends nothing.'
  task :invite_preview, [:to] => :environment do |_task, args|
    to = args[:to].presence || ENV.fetch('TO', 'invitee@example.com')

    # An unsaved User with a freshly generated token — enough for the mailer
    # to render exactly what a real invitee would receive.
    user = User.new(email: to, first_name: 'Test', last_name: 'Invitee')
    raw_token, encoded = Devise.token_generator.generate(User, :invitation_token)
    user.invitation_token = encoded
    user.invitation_created_at = Time.current
    user.invitation_sent_at = Time.current

    mail = Devise.mailer.invitation_instructions(user, raw_token)

    puts "from    : #{Array(mail.from).join(', ')}"
    puts "to      : #{Array(mail.to).join(', ')}"
    puts "subject : #{mail.subject}"
    puts "mailer  : #{Devise.mailer} (parent: #{Devise.parent_mailer})"
    puts '-' * 72
    puts(mail.text_part&.body&.decoded || mail.body.decoded)
    puts '-' * 72
    puts 'Rendered cleanly. Nothing was saved and nothing was sent.'
  end
end
