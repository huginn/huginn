class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def action_missing(name)
    case name.to_sym
    when *Devise.omniauth_providers
      option_provider = ServiceOptionProviders::DefaultServiceOptionProvider.new
      service = current_user.services.initialize_or_update_via_omniauth(request.env['omniauth.auth'], option_provider)
      if service && service.save
        redirect_to services_path, notice: "The service was successfully created."
      else
        redirect_to services_path, error: "Error creating the service."
      end
    else
      raise ActionController::RoutingError, 'not found'
    end
  end

  define_method "37signals" do
    option_provider = ServiceOptionProviders::ThirtySevenSignalsOptionProvider.new
    service = current_user.services.initialize_or_update_via_omniauth(request.env['omniauth.auth'], option_provider)
    if service && service.save
      redirect_to services_path, notice: "The service was successfully created."
    else
      redirect_to services_path, error: "Error creating the service."
    end
  end
end
