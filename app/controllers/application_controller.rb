class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  before_action :require_onboarding

  # Handle authorization errors by redirecting to root with an alert
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: exception.message
  end

  before_action :update_allowed_parameters, if: :devise_controller?

  def update_allowed_parameters
    devise_parameter_sanitizer.permit(:sign_up) { |u| u.permit(:first_name, :last_name, :email, :password) }
    devise_parameter_sanitizer.permit(:account_update) { |u| u.permit(:first_name, :last_name, :email, :password, :current_password) }
    devise_parameter_sanitizer.permit(:invite, keys: %i[email first_name last_name phone_number role])
  end

  private

  def require_onboarding
    return unless user_signed_in?
    return if devise_controller?
    return if current_user.onboarding_complete?

    redirect_to new_client_path,
                alert: 'Finish setting up your organiser profile.'
  end
end
