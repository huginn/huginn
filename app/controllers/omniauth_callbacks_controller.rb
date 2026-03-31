class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def action_missing(name)
    case name.to_sym
    when *Devise.omniauth_providers
      reauthorization_service = reauthorization_service_for(name)
      service = reauthorization_service || current_user.services.initialize_or_update_via_omniauth(request.env['omniauth.auth'])
      service.assign_via_omniauth(request.env["omniauth.auth"]) if reauthorization_service

      if service && service.save
        redirect_to services_path, notice: reauthorization_service ? "The service was successfully reauthorized." : "The service was successfully created."
      else
        redirect_to services_path, error: "Error creating the service."
      end
    else
      raise ActionController::RoutingError, 'not found'
    end
  end

  private

  def reauthorization_service_for(provider)
    origin = request.env["omniauth.origin"].to_s
    match = origin.match(/\Areauthorize_service:(\d+)\z/)
    return unless match

    service_id = match[1]

    current_user.services.find_by(id: service_id, provider: provider.to_s)
  end
end
