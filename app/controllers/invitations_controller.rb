class InvitationsController < Devise::InvitationsController
  before_action :authenticate_user!, only: %i[new create]
  before_action :require_inviter!, only: %i[new create]

  def create
    requested = requested_role

    return reject_with(:role, "isn't a role you can assign") unless current_user.assignable_roles.include?(requested)
    return reject_with(:client_id, 'must be chosen for this role') if requested != 'admin' && resolved_client_id.blank?

    super do |user|
      user.add_role(requested) if user.persisted? && user.errors.empty?
      return redirect_to users_path, notice: 'Invitation sent successfully.' if user.persisted? && user.errors.empty?
    end
  end

  private

  def requested_role
    params.dig(:user, :role).to_s
  end

  # An organiser can only ever invite into their own client — the form doesn't
  # offer a picker, and this ignores one if it's posted anyway. Only an admin
  # chooses, and only when the invitee isn't an admin.
  def resolved_client_id
    return nil if requested_role == 'admin'

    if current_user.has_role?(:admin)
      chosen = params.dig(:user, :client_id).presence
      chosen if Client.exists?(id: chosen)
    else
      current_user.client_id
    end
  end

  # devise_invitable builds the invitee from this, so merging the client here
  # sets it as part of the same save rather than patching it afterwards.
  def invite_params
    params.require(:user)
      .permit(:email, :first_name, :last_name, :phone_number)
      .merge(client_id: resolved_client_id)
  end

  def reject_with(field, message)
    self.resource = User.new(
      params.require(:user).permit(:email, :first_name, :last_name, :phone_number)
    )
    resource.errors.add(field, message)
    render :new, status: :unprocessable_entity
  end

  def require_inviter!
    return if current_user.can_invite?

    redirect_to root_path, alert: "You don't have permission to invite users."
  end
end
