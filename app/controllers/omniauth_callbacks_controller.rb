require 'ldap_settings'
require 'ldap_user_resolver'

class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Dedicated LDAP *login* callback. This is separate from the generic
  # action_missing handler below, which connects an external service to the
  # already-signed-in current_user (the "Services" feature) and must not be
  # reused to establish a login session. CSRF is enforced by Rails on the POST
  # that carries the credentials (the sign-in form includes the authenticity
  # token); it is not skipped for this action.
  def ldap
    user = LdapUserResolver.resolve(request.env['omniauth.auth'])

    if user&.persisted? && user.active_for_authentication?
      sign_in(user, event: :authentication)
      set_flash_message(:notice, :success, kind: 'LDAP') if is_navigational_format?
      redirect_to after_sign_in_path_for(user)
    else
      flash[:alert] = 'LDAP login failed.'
      redirect_to new_user_session_path
    end
  end

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
