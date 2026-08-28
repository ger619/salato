# app/controllers/users/registrations_controller.rb
  class RegistrationsController < Devise::RegistrationsController
    protected

    def after_sign_up_path_for(resource)
      resource.roles.reload
      resource.organiser? ? new_onboarding_clients_path : root_path
    end

    def sign_up_params
      params.require(:user).permit(
        :first_name, :last_name, :email, :phone,
        :password, :password_confirmation, :signup_role
      )
    end
  end
