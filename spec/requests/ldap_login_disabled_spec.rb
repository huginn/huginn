require 'rails_helper'
require 'ldap_settings'

# With no LDAP_* environment set (the default in the test suite) the feature is
# completely inert: no setting, no provider, no route, no middleware — i.e. no
# behaviour change for an installation that does not opt in.
describe 'LDAP login disabled by default' do
  it 'reports the feature as disabled' do
    expect(LdapSettings).not_to be_enabled
  end

  it 'does not register the :ldap omniauth provider' do
    expect(Devise.omniauth_providers).not_to include(:ldap)
  end

  it 'generates no LDAP callback route' do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:user_ldap_omniauth_callback_path)
  end

  it 'adds no LDAP middleware to the stack' do
    names = Rails.application.config.middleware.map(&:name)
    expect(names).not_to include('Rack::LdapCredentialsGuard')
  end
end
