# app/controllers/users/registrations_controller.rb

class RegistrationsController < Devise::RegistrationsController
  protected

  def after_sign_up_path_for(resource)
    resource.organiser? ? new_onboarding_client_path : root_path
  end

  def sign_up_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :phone,
      :password, :password_confirmation, :role
    ).tap do |p|
      # never trust role from the form — admin must be set manually
      p[:role] = 'buyer' unless %w[buyer organiser].include?(p[:role])
    end
  end
end
