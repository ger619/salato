module Interactions
  # Updates a user's roles and, for admins, their name and client.
  # Only roles the acting user may manage are added or removed;
  # any other roles the user already has stay as they are.
  #
  #   Users::UpdateAccess.call(actor: current_user, user: @user, profile: {...}, role_ids: [...])
  #   # => true when saved; false with the reasons in user.errors
  class UpdateAccess
    HIDDEN_FROM_ADMINS = %w[editor creator].freeze
    ORGANISERS_CAN_ASSIGN = %w[organiser scanner].freeze

    # Used by the edit view too, so the checkboxes and the server always agree.
    def self.assignable_roles(actor)
      roles = Role.order(:name)
      return roles.where.not(name: HIDDEN_FROM_ADMINS) if actor.has_role?(:admin)

      roles.where(name: ORGANISERS_CAN_ASSIGN)
    end

    def self.call(**args) = new(**args).call

    def initialize(actor:, user:, profile: {}, role_ids: [])
      @actor = actor
      @user = user
      @profile = profile.to_h.stringify_keys
      @role_ids = Array(role_ids)
    end

    def call
      # IDs are UUIDs, so compare them as strings.
      manageable_ids = self.class.assignable_roles(@actor).pluck(:id).map(&:to_s)
      current_ids = @user.role_ids.map(&:to_s)
      chosen_ids = @role_ids.map(&:to_s).compact_blank & manageable_ids
      new_ids = ((current_ids - manageable_ids) + chosen_ids).uniq

      return fail_with('must include at least one role') if new_ids.empty?
      return fail_with("can't remove your own admin role") if removing_own_admin?(current_ids, new_ids)

      # role_ids= writes to the join table immediately, so it shares a transaction with the save.
      saved = User.transaction do
        @user.assign_attributes(@profile.slice('first_name', 'last_name', 'client_id')) if admin?
        @user.role_ids = new_ids
        @user.save || raise(ActiveRecord::Rollback)
      end

      saved == true
    end

    private

    def admin? = @actor.has_role?(:admin)

    def removing_own_admin?(current_ids, new_ids)
      admin_id = Role.find_by(name: 'admin')&.id&.to_s
      @user == @actor && admin_id.present? && current_ids.include?(admin_id) && !new_ids.include?(admin_id)
    end

    def fail_with(message)
      @user.errors.add(:roles, message)
      false
    end
  end
end
