# app/queries/ticket_filter.rb
class TicketFilter
  def self.call(scope, params)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(ticket_type_id: params[:ticket_type_id]) if params[:ticket_type_id].present?
    scope = scope.where(checked_in: params[:checked_in] == 'true') if params[:checked_in].present?
    scope
  end
end
