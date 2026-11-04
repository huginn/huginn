# frozen_string_literal: true

# Central place that derives the optional LDAP login configuration from the
# environment. The whole feature is OFF unless LDAP_HOST is set, so an existing
# installation that sets none of these variables behaves exactly as before.
#
# A deliberate security choice: omniauth-ldap defaults its connection method to
# :plain (clear text). We invert that here so the default is encrypted
# (StartTLS); clear text is only used when an operator explicitly asks for it
# with LDAP_METHOD=plain.
module LdapSettings
  # ENV value => omniauth-ldap :method value.
  #   tls   -> StartTLS on the LDAP port (default)
  #   ssl   -> LDAPS (implicit TLS, usually port 636)
  #   plain -> no encryption (opt-in only)
  METHODS = { 'tls' => :tls, 'ssl' => :ssl, 'plain' => :plain }.freeze
  DEFAULT_METHOD = :tls

  module_function

  # The switch. Without a host there is no provider, route or form.
  def enabled?
    ENV['LDAP_HOST'].to_s.strip != ''
  end

  def host
    ENV['LDAP_HOST'].to_s.strip
  end

  def base
    ENV['LDAP_BASE'].to_s.strip
  end

  # The LDAP attribute that carries the login name (uid for OpenLDAP,
  # sAMAccountName for Active Directory).
  def uid
    value = ENV['LDAP_UID'].to_s.strip
    value.empty? ? 'uid' : value
  end

  def method
    key = ENV['LDAP_METHOD'].to_s.strip.downcase
    return DEFAULT_METHOD if key.empty?

    METHODS[key] || raise(ArgumentError, "LDAP_METHOD must be one of: #{METHODS.keys.join(', ')}")
  end

  def encrypted?
    method != :plain
  end

  def port
    value = ENV['LDAP_PORT'].to_s.strip
    return Integer(value) unless value.empty?

    method == :ssl ? 636 : 389
  end

  # Certificates are verified unless an operator explicitly opts out (e.g. for a
  # self-signed lab server). Opting out only disables verification, never
  # encryption.
  def verify_certificates?
    ENV['LDAP_DISABLE_VERIFY_CERTIFICATES'].to_s.strip != 'true'
  end

  def ca_file
    value = ENV['LDAP_CA_FILE'].to_s.strip
    value.empty? ? nil : value
  end

  # New local accounts are only provisioned from LDAP when explicitly enabled.
  def auto_create?
    ENV['LDAP_AUTO_CREATE'].to_s.strip == 'true'
  end

  def title
    value = ENV['LDAP_TITLE'].to_s.strip
    value.empty? ? 'LDAP' : value
  end

  # Options passed to `config.omniauth :ldap, ...`. Only built when enabled.
  def omniauth_options
    raise 'LDAP_BASE is required when LDAP_HOST is set' if base.empty?

    options = {
      title: title,
      host: host,
      port: port,
      method: method,
      base: base,
      uid: uid,
      # Trim surrounding whitespace from the submitted login before it reaches
      # the directory filter.
      name_proc: ->(login) { login.to_s.strip }
    }

    bind_dn = ENV['LDAP_BIND_DN'].to_s.strip
    bind_pw = ENV['LDAP_BIND_PW'].to_s
    options[:bind_dn] = bind_dn unless bind_dn.empty?
    options[:password] = bind_pw unless bind_pw.empty?

    filter = ENV['LDAP_FILTER'].to_s.strip
    options[:filter] = filter unless filter.empty?

    if encrypted?
      # omniauth-ldap derives the OpenSSL verify_mode from this flag: false (the
      # default) uses SSLContext::DEFAULT_PARAMS, which verifies the peer against
      # the system trust store; true falls back to VERIFY_NONE. A custom CA (for
      # a self-signed server) is merged on top via :tls_options.
      options[:disable_verify_certificates] = !verify_certificates?
      options[:tls_options] = { ca_file: ca_file } if ca_file
    end

    options
  end
end
