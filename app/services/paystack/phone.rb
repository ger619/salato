module Paystack
  class Phone
    # "0712 345 678", "712345678", "254712345678", "+254712345678" → "+254712345678"
    def self.kenyan(raw)
      digits = raw.to_s.gsub(/\D/, '')
      digits = digits.sub(/\A0/, '254') if digits.start_with?('0')
      digits = "254#{digits}" if digits.length == 9

      return nil unless digits.match?(/\A254[17]\d{8}\z/)

      "+#{digits}"
    end
  end
end
