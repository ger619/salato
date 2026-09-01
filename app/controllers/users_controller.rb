class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_people_access!, only: %i[index show]
  def index
    users_scope = visible_users.includes(:roles).order(:first_name, :last_name, :email)

    @per_page = 10
    @page = (params[:page] || 1).to_i
    offset = (@page - 1) * @per_page

    @total_count = users_scope.count
    @total_pages = (@total_count / @per_page.to_f).ceil
    @start_count = offset + 1
    @end_count = [offset + @per_page, @total_count].min

    @users = users_scope.limit(@per_page).offset(offset)
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
