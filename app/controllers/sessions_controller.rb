class SessionsController < Devise::SessionsController
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)

    respond_to do |format|
      format.json { render json: { location: after_sign_in_path_for(resource) } }
      format.html { respond_with(resource, location: after_sign_in_path_for(resource)) }
    end
  end
end
