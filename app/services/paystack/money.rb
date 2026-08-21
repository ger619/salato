module Paystack
  class Money
    def self.to_subunit(amount)
      (BigDecimal(amount.to_s) * 100).to_i
    end
  end
end
