class TicketVerificationsController < ApplicationController
  before_action :authenticate_user!, only: :check_in
  before_action :set_ticket, only: %i[show check_in]
  before_action :authorise_scanner!, only: :check_in
  before_action :ensure_check_in_window!, only: :check_in

  # GET /verify
  # Just the scanner page. No lookup happens here any more.
  def new
    @query = ''
  end

  # POST /verify/lookup
  # One entry point for both paths: the camera fills the form and submits it,
  # and typing a number by hand submits the same form.
  def lookup
    @query = extract_token(params[:token])

    return redirect_to new_verification_path, alert: 'Nothing was scanned. Try again.' if @query.blank?

    ticket = Ticket.find_by(qr_token: @query) ||
             Ticket.find_by(ticket_number: @query.upcase)

    if ticket
      redirect_to verify_ticket_path(ticket.qr_token)
    else
      # 422, not 404 — Turbo only renders the body of a failed form submission
      # when the status is in the 4xx range it treats as a form error.
      render :invalid, status: :unprocessable_entity
    end
  end

  # GET /verify/:token
  def show
    # Drives whether the view renders the check-in button or just the status.
    # Same window the controller enforces, so the button never appears when
    # pressing it would only produce an error.
    @event = @ticket.event
    @check_in_open = @event&.check_in_open?
    @can_check_in = user_signed_in? && @event.present? && @check_in_open

    # Lets the view say *when* scanning starts rather than just refusing.
    @check_in_opens_at = @event&.check_in_opens_at
  end

  # POST /verify/:token/check_in
  def check_in
    # Atomic: the WHERE clause is the guard. Only one concurrent request can
    # match a row that is still 'valid', so a double scan can't double check in.
    claimed = Ticket
      .where(id: @ticket.id, status: 'valid')
      .update_all(status: 'checked_in', checked_in_at: Time.current)

    @ticket.reload

    if claimed == 1
      redirect_to verify_ticket_path(@ticket.qr_token),
                  notice: "Checked in — #{@ticket.attendee_name}."
    elsif @ticket.checked_in?
      redirect_to verify_ticket_path(@ticket.qr_token),
                  alert: "Already checked in at #{@ticket.checked_in_at.strftime('%-l:%M %p')}."
    else
      redirect_to verify_ticket_path(@ticket.qr_token),
                  alert: 'This ticket is not valid.'
    end
  end

  private

  def set_ticket
    @ticket = Ticket
      .includes(:event, :ticket_type, :order)
      .find_by(qr_token: params[:token])

    return if @ticket

    @query = params[:token].to_s
    render :invalid, status: :not_found
  end

  # A QR code usually carries a full URL, not a bare token. Accepts:
  #   "SAL-4F2A9C"                       -> as typed
  #   "https://salato.co/verify/abc123"  -> abc123
  #   "https://salato.co/v?token=abc123" -> abc123
  def extract_token(raw)
    value = raw.to_s.strip
    return value unless value.match?(%r{\Ahttps?://}i)

    uri = begin
      URI.parse(value)
    rescue URI::InvalidURIError
      nil
    end
    return value unless uri

    from_query = Rack::Utils.parse_nested_query(uri.query.to_s)['token']
    from_query.presence || uri.path.split('/').reject(&:blank?).last.to_s
  end

  def authorise_scanner!
    return if @ticket.event

    redirect_to verify_ticket_path(@ticket.qr_token),
                alert: "You can't check in tickets for this event."
  end

  def ensure_check_in_window!
    event = @ticket.event

    if event.start_at.blank?
      return redirect_to verify_ticket_path(@ticket.qr_token),
                         alert: "This event has no start time set, so tickets can't be scanned yet."
    end

    return if event.check_in_open?

    message =
      if Time.current < event.check_in_opens_at
        "Too early — scanning opens #{event.check_in_opens_at.strftime('%-l:%M %p on %a %-d %b')}."
      else
        "Too late — check-in for this event closed #{event.check_in_closes_at.strftime('%-l:%M %p')}."
      end

    redirect_to verify_ticket_path(@ticket.qr_token), alert: message
  end
end
