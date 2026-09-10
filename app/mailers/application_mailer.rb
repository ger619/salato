class ApplicationMailer < ActionMailer::Base
  # salato.app is the domain verified in Resend. A From address on any
  # other domain is rejected at send time, so keep this on salato.app.
  default from: ENV.fetch('MAIL_FROM', 'Salato <hello@salato.app>')
  layout 'mailer'
end
