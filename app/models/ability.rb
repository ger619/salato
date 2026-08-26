class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.blank?

    if user.has_role?(:admin)
      can :manage, :all
      return
    end

    if user.has_role?(:organiser)
      # Their own events, and everything hanging off them.
      can :manage, Event, user_id: user.id
      can :manage, TicketType, event: { user_id: user.id }
      can :read, Order, event: { user_id: user.id }
      can %i[read check_in], Ticket, event: { user_id: user.id }
      can :read, User
      can :invite, User
    end

    return unless user.has_role?(:scanner)

    can :read, Event
    can %i[read check_in], Ticket
  end
end
