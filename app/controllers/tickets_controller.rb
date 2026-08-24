class TicketsController < ApplicationController
  before_action :set_ticket
  before_action :set_position, only: :show

  def show; end

  def download
    send_data(
      TicketPdf.generate(@ticket),
      filename: "#{@ticket.ticket_number}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end

  private

  def set_ticket
    @ticket = Ticket
      .includes(:event, :ticket_type, :order)
      .find(params[:id])
  end

  # Where this ticket sits in its order, so the page can say "2 of 3" and
  # link back to the rest. Same ordering the order page and PDF use.
  def set_position
    numbers = @ticket.order.tickets.order(:ticket_number).pluck(:ticket_number)

    @order_size = numbers.size
    @position = numbers.index(@ticket.ticket_number).to_i + 1
  end
end
