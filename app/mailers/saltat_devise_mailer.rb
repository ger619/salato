# app/mailers/salato_devise_mailer.rb
#
# Every Devise email (confirmation, reset password, unlock, password/email
# changed, and devise_invitable's invitation) goes through devise_mail, so the
# logo is attached here once.
#
# The logo is embedded in the email itself (an inline "cid:" attachment), not
# linked from the website — so it shows in Gmail/Outlook in development and
# production without needing asset_host or a public URL.
class SalatoDeviseMailer < Devise::Mailer
  default template_path: 'devise/mailer'

  LOGO_PATH = Rails.root.join('app/assets/images/salato_logo/salato-logo-horizontal.png')

  protected

  def devise_mail(record, action, opts = {}, &block)
    attach_logo
    super
  end

  private

  def attach_logo
    return unless File.exist?(LOGO_PATH)

    attachments.inline['salato-logo-horizontal.png'] = File.binread(LOGO_PATH)
    @logo_url = attachments['salato-logo-horizontal.png'].url # => "cid:..."
  end
end