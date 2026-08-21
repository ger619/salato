class TicketsController < ApplicationController
  def show
    @ticket = Ticket
      .includes(:event, :ticket_type, :order)
      .find(params[:id])
  end

  def download
    @ticket = Ticket
      .includes(:event, :ticket_type, :order)
      .find(params[:id])

    pdf = TicketPdf.generate(@ticket)

    send_data(
      pdf,
      filename: "#{@ticket.ticket_number}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end
end
