class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_people_access!, only: %i[index show]

  def index
    # includes(:roles) — without it rolify fires a query per row.
    @users = visible_users.includes(:roles).order(:first_name, :last_name, :email)
  end

  def show
    @user = visible_users.includes(:roles).find(params[:id])
  end

  def status
    @user = User.find(params[:id])
    @user.toggle_boolean(:status)
    redirect_to users_path, notice: 'User status was successfully updated.'
  end

  private

  # Admins see everyone. An organiser sees their own client's people only —
  # so this scope, not the view, is what keeps clients apart.
  def visible_users
    return User.all if current_user.has_role?(:admin)

    User.where(client_id: current_user.client_id)
  end

  def require_people_access!
    return if current_user.has_role?(:admin) || current_user.has_role?(:organiser)

    redirect_to root_path, alert: "You don't have access to that."
  end
end
