class ModalFailureApp < Devise::FailureApp
  def respond
    if request.format == :json || request.xhr?
      json_failure
    else
      super
    end
  end

  private

  def json_failure
    self.status = 401
    self.content_type = 'application/json'
    self.response_body = { error: i18n_message }.to_json
  end
end
