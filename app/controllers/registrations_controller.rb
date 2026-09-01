# app/controllers/users/registrations_controller.rb
class RegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = {})
    super
    resource.build_client if resource.client.nil?
  end

  def after_sign_up_path_for(_resource)
    root_path
  end

  def sign_up_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :phone_number, :id_photo,
      :password, :password_confirmation,
      client_attributes: %i[name phone email website country city description]
    )
  end
end
