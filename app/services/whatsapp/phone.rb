# app/services/whatsapp/phone.rb
#
# Buyers type "0712 345 678" into the order form. WhatsApp addresses a chat
# by JID: full international number, digits only, no "+", then "@c.us".
#
#   0712345678      -> 254712345678@c.us
#   +254 712 345678 -> 254712345678@c.us
#   712345678       -> 254712345678@c.us
#   00254712345678  -> 254712345678@c.us
#
# Anything that does not end up as 254 + 9 digits returns nil, and the caller
# skips the send rather than firing a message into the void.
module Whatsapp
  module Phone
    COUNTRY_CODE = '254'.freeze

    # National significant number length after the country code (KE mobiles:
    # 7XXXXXXXX and 1XXXXXXXX).
    NSN_LENGTH = 9

    def self.to_jid(raw, country_code: COUNTRY_CODE)
      msisdn = normalise(raw, country_code: country_code)

      return nil if msisdn.blank?

      "#{msisdn}@c.us"
    end

    # Returns the bare international number ("254712345678") or nil.
    def self.normalise(raw, country_code: COUNTRY_CODE)
      digits = raw.to_s.gsub(/\D/, '')

      return nil if digits.blank?

      digits = digits.sub(/\A00/, '') # 00254... -> 254...
      digits = digits.sub(/\A0/, country_code) # 07...    -> 2547...

      digits = "#{country_code}#{digits}" unless digits.start_with?(country_code) # 7...     -> 2547...

      return nil unless digits.match?(/\A#{country_code}\d{#{NSN_LENGTH}}\z/)

      digits
    end
  end
end
