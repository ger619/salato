module Paystack
  class Money
    def self.subunit(amount)
      (BigDecimal(amount.to_s) * 100).to_i
    end
  end
end
