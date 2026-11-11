# frozen_string_literal: true

module Rack
  # Rejects an LDAP login POST that carries a blank (empty or whitespace-only)
  # username or password BEFORE the omniauth-ldap strategy runs and performs the
  # directory bind.
  #
  # The strategy itself already refuses a zero-length username/password before
  # binding (which is what blocks the LDAP "unauthenticated bind" that an empty
  # password can trigger), but its check is `.empty?` only and lets a
  # whitespace-only value through to the bind. This guard closes that gap and
  # keeps the "reject before bind" guarantee explicit and testable.
  class LdapCredentialsGuard
    def initialize(app, path:)
      @app = app
      @path = path
    end

    def call(env)
      if env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == @path && blank_credentials?(env)
        return [
          302,
          { 'Location' => '/users/sign_in', 'Content-Type' => 'text/plain' },
          ['LDAP login failed.']
        ]
      end

      @app.call(env)
    end

    private

    def blank_credentials?(env)
      request = Rack::Request.new(env)
      params = request.POST # reads and rewinds rack.input
      params['username'].to_s.strip.empty? || params['password'].to_s.strip.empty?
    rescue StandardError
      # If the body cannot be parsed, let the normal stack handle the request
      # rather than failing closed in a confusing way.
      false
    end
  end
end
