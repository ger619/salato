class InvitationsController < Devise::InvitationsController
  before_action :authenticate_user!, only: %i[new create]
  before_action :require_inviter!, only: %i[new create]

  def create
    requested = params.dig(:user, :role).to_s

    # Re-checked server side. The select only offers permitted roles, but
    # the select is not a security boundary.
    unless current_user.assignable_roles.include?(requested)
      self.resource = User.new(email: params.dig(:user, :email))
      resource.errors.add(:role, "isn't a role you can assign")
      render :new, status: :unprocessable_entity
      return
    end

    super do |user|
      user.add_role(requested) if user.persisted? && user.errors.empty?
    end
  end

  private

  def require_inviter!
    return if current_user.can_invite?

    redirect_to root_path, alert: "You don't have permission to invite users."
  end
end
