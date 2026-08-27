class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    if user.has_role? :admin
      can :manage, :all

    elsif user.has_role? :organiser
      # Their own events, and everything hanging off them.
      can :manage, Event, user_id: user.id
      can :manage, TicketType, event: { user_id: user.id }
      can :read, Order, event: { user_id: user.id }
      can %i[read check_in], Ticket, event: { user_id: user.id }
      can :read, User
      can :invite, User

    elsif user.has_role?(:scanner)
      can :read, Event
      can %i[organiser organiser_show], Event

      can %i[read check_in], Ticket
    else
      can :read, Event
    end
  end
end
