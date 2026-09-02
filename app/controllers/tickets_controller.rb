class TicketsController < ApplicationController
  before_action :set_ticket, except: :index
  before_action :set_position, only: :show

  def index
    @query = params[:q].to_s.strip
    @status = params[:status].presence
    @event_id = params[:event_id].presence

    @events = Event.all
    scope = Ticket.includes(:event, :ticket_type, :order)

    unless current_user&.has_any_role?(:admin)
      @events = @events.joins(:users).where(users: { id: current_user.id }).distinct
      scope = scope.joins(event: :users).where(users: { id: current_user.id }).distinct
    end

    scope = scope.where(event_id: @event_id) if @event_id.present?
    scope = scope.where(status: @status) if @status.present?

    if @query.present?
      q = "%#{@query.downcase}%"
      scope = scope.joins(:event).where(
        <<~SQL.squish,
          LOWER(tickets.attendee_name) LIKE :q
          OR LOWER(tickets.attendee_email) LIKE :q
          OR LOWER(tickets.ticket_number) LIKE :q
          OR LOWER(events.name) LIKE :q
        SQL
        q: q
      )
    end

    scope = scope.order(created_at: :desc)

    @statuses = scope.unscope(:select, :order).distinct.pluck(:status).compact.sort

    @per_page = 10
    @page = [params[:page].to_i, 1].max
    offset = (@page - 1) * @per_page

    @total_count = scope.count
    @total_pages = (@total_count / @per_page.to_f).ceil
    @start_count = @total_count.zero? ? 0 : offset + 1
    @end_count = [offset + @per_page, @total_count].min
    @tickets = scope.limit(@per_page).offset(offset)
    @total = @total_count
  end

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
