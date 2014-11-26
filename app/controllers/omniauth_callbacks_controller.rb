class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def action_missing(name)
    case name.to_sym
    when *Devise.omniauth_providers
      service = current_user.services.initialize_or_update_via_omniauth(request.env['omniauth.auth'])
      if service && service.save
        redirect_to services_path, notice: "The service was successfully created."
      else
        redirect_to services_path, error: "Error creating the service."
      end
    else
      raise ActionController::RoutingError, 'not found'
    end
  end
end
