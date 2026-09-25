class PhoneNormalizer
  # Kenyan numbers in, "2547XXXXXXXX" out. Returns nil if it can't be trusted.
  def self.call(raw)
    digits = raw.to_s.gsub(/\D/, "")
    digits = "254#{digits[1..]}" if digits.start_with?("0")
    digits = "254#{digits}"      if digits.length == 9 && digits.start_with?("7", "1")
    return nil unless digits.match?(/\A254(7|1)\d{8}\z/)

    digits
  end
end