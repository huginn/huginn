# frozen_string_literal: true

# Maps a successful LDAP bind (an OmniAuth auth hash) to a Huginn user.
#
# The mapping is by USERNAME ONLY. It never matches on the email address, so an
# LDAP account cannot take over a pre-existing local account that happens to
# share an email. A new local account is provisioned only when auto-creation is
# explicitly enabled (LDAP_AUTO_CREATE=true); otherwise an unknown LDAP user is
# rejected.
module LdapUserResolver
  module_function

  # Returns the signed-in-able Huginn user, or nil when the login must be
  # rejected.
  def resolve(auth)
    username = extract_username(auth)
    return nil if username.blank?

    user = User.where('lower(username) = ?', username.downcase).first
    return user if user

    LdapSettings.auto_create? ? create(auth, username) : nil
  end

  # The directory username, never the email. omniauth-ldap maps the login
  # attribute (uid / userid / sAMAccountName) to info.nickname, which is a plain
  # string and works for both OpenLDAP and Active Directory; the raw entry is
  # only a fallback.
  def extract_username(auth)
    return '' if auth.nil?

    nickname = auth.dig('info', 'nickname')
    return nickname.to_s.strip if nickname.to_s.strip != ''

    raw = auth.dig('extra', 'raw_info')
    value = raw && (raw[LdapSettings.uid] || raw[LdapSettings.uid.to_sym])
    Array(value).first.to_s.strip
  end

  # Minimal provisioning for auto-create mode (default OFF). The account
  # authenticates through LDAP, so the local password is random and unused.
  def create(auth, username)
    return nil unless username.match?(/\A[a-zA-Z0-9_-]{3,190}\z/)

    email = auth.dig('info', 'email').to_s.strip
    email = "#{username}@ldap.invalid" if email.empty?

    user = User.new(username: username, email: email)
    user.password = user.password_confirmation = SecureRandom.hex(32)
    user.requires_no_invitation_code!
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save ? user : nil
  end
end
