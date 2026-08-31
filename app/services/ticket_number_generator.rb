class TicketNumberGenerator
  def self.generate
    loop do
      number = "SAL-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(5).upcase}"
      break number unless Ticket.exists?(ticket_number: number)
    end
  end
end
