# frozen_string_literal: true

require 'ldap_settings'

# Insert the pre-bind credential guard only when LDAP login is enabled, so an
# installation without LDAP keeps its middleware stack unchanged. The guard runs
# before OmniAuth so that blank credentials are rejected before any directory
# bind. The callback path can be overridden with LDAP_CALLBACK_PATH if a
# deployment mounts Devise under a different scope.
if LdapSettings.enabled?
  require 'rack/ldap_credentials_guard'

  # Devise sets config.omniauth_path_prefix = "/auth", so the callback is
  # /auth/ldap/callback (not the default /users/auth/...).
  callback_path = ENV['LDAP_CALLBACK_PATH'].to_s.strip
  callback_path = '/auth/ldap/callback' if callback_path.empty?

  # Insert at the very front of the stack. OmniAuth's middleware is added by
  # Devise after the app initializers run, so it is not a stable anchor for
  # insert_before here; position 0 always exists and guarantees the guard runs
  # before OmniAuth processes the callback. It is a no-op for every path except
  # the LDAP callback POST.
  Rails.application.config.middleware.insert_before(
    0,
    Rack::LdapCredentialsGuard,
    path: callback_path
  )
end
