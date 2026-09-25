class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_people_access!, only: %i[index show edit update status]
  before_action :set_user, only: %i[show edit update status]

  helper_method :assignable_roles

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

  def show; end

  def edit; end

  def update
    saved = Interactions::UpdateAccess.call(
      actor: current_user,
      user: @user,
      profile: user_params.slice(:first_name, :last_name, :client_id),
      role_ids: user_params[:role_ids]
    )

    if saved
      redirect_to user_path(@user), notice: "#{@user.full_name.presence || @user.email} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def status
    return redirect_back fallback_location: user_path(@user), alert: "You can't change your own status." if @user == current_user

    @user.toggle_boolean(:status)
    redirect_back fallback_location: user_path(@user), notice: 'User status was successfully updated.'
  end

  private

  # Scoped, so an organiser can't open or change another client's people by editing the URL.
  def set_user
    @user = visible_users.includes(:roles).find(params[:id])
  end

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

  def user_params
    params.expect(user: [:first_name, :last_name, :client_id, { role_ids: [] }])
  end

  def assignable_roles
    Interactions::UpdateAccess.assignable_roles(current_user)
  end
end
