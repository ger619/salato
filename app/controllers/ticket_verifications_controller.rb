class TicketVerificationsController < ApplicationController
  def show
    @ticket = Ticket
      .includes(:event, :ticket_type)
      .find_by!(qr_token: params[:token])
  end

  def check_in
    @ticket = Ticket.find_by!(
      qr_token: params[:token]
    )

    if @ticket.checked_in?
      redirect_to verify_ticket_path(@ticket.qr_token),
                  alert: 'This ticket has already been checked in.'
      return
    end

    unless @ticket.valid_ticket?
      redirect_to verify_ticket_path(@ticket.qr_token),
                  alert: 'This ticket is not valid.'
      return
    end

    @ticket.update!(
      status: 'checked_in',
      checked_in_at: Time.current
    )

    redirect_to verify_ticket_path(@ticket.qr_token),
                notice: 'Ticket checked in successfully.'
  end
end
