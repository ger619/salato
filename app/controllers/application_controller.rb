class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: exception.message
  end

  before_action :update_allowed_parameters, if: :devise_controller?

  def update_allowed_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(:first_name, :last_name, :email, :phone_number,
               :password, :password_confirmation,
               client_attributes: %i[name phone email website country city description])
    end

    devise_parameter_sanitizer.permit(:account_update) do |u|
      u.permit(:first_name, :last_name, :email, :phone_number,
               :password, :current_password)
    end

    devise_parameter_sanitizer.permit(:invite, keys: %i[email first_name last_name phone_number role])
  end
end