class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!, only: :index

  def index
    # includes(:roles) — without it rolify fires a query per row.
    @users = User.includes(:roles).order(:first_name, :last_name, :email)
  end

  def show
    @user = User.includes(:roles).find(params[:id])
  end

  private

  def require_admin!
    return if current_user.has_role?(:admin)

    redirect_to root_path, alert: "You don't have access to that."
  end
end
