class DashboardController < ApplicationController
  before_action :authenticate_user!

  WINDOW = 30 # days

  def index
    @range = WINDOW.days.ago.beginning_of_day..Time.current
    @prev_range = (WINDOW * 2).days.ago.beginning_of_day..WINDOW.days.ago.beginning_of_day

    orders = scoped_orders.where(created_at: @range)
    prev_orders = scoped_orders.where(created_at: @prev_range)

    @revenue = orders.sum(:total_price)
    @prev_revenue = prev_orders.sum(:total_price)
    @tickets_sold = orders.sum(:quantity)
    @prev_tickets = prev_orders.sum(:quantity)
    @order_count = orders.count
    @prev_orders = prev_orders.count

    # Daily revenue for the area chart, zero-filled so gaps don't collapse.
    daily = orders.group('DATE(created_at)').sum(:total_price)
    @revenue_series = (@range.first.to_date..Date.current).map do |day|
      [day, daily[day] || daily[day.to_s] || 0]
    end

    daily_tickets = orders.group('DATE(created_at)').sum(:quantity)
    @tickets_series = (@range.first.to_date..Date.current).map do |day|
      daily_tickets[day] || daily_tickets[day.to_s] || 0
    end

    @recent_orders = scoped_orders.includes(:event, :ticket_type)
      .order(created_at: :desc)
      .limit(8)

    @top_events = scoped_events
      .joins(:orders)
      .where(orders: { status: 'paid' })
      .group('events.id')
      .select('events.*, SUM(orders.total_price) AS gross, SUM(orders.quantity) AS sold')
      .order('gross DESC')
      .limit(5)

    @upcoming = scoped_events.where('start_at > ?', Time.current).order(:start_at).limit(4)
  end

  private

  # Admins see everything; organisers see only their own events.
  # Adjust the admin check to whatever your User model exposes.
  def admin?
    current_user.respond_to?(:admin?) && current_user.admin?
  end

  def scoped_events
    admin? ? Event.all : Event.where(user_id: current_user.id)
  end

  def scoped_orders
    base = Order.where(status: 'paid')
    admin? ? base : base.where(event_id: scoped_events.select(:id))
  end
end
