require 'rails_helper'

# End-to-end LDAP login against a live test directory. Opt-in only: it runs when
# LDAP_INTEGRATION=true AND the app was booted with the LDAP_* settings pointed
# at the test server (so the :ldap provider and its route exist). It never runs
# in the normal suite. The test users are supplied via ENV, so the same spec
# works against OpenLDAP and against Active Directory.
#
# Core ENV (set when invoking rspec):
#   LDAP_INTEGRATION=true
#   LDAP_HOST / LDAP_BASE / LDAP_UID / LDAP_METHOD / LDAP_CA_FILE / LDAP_FILTER
#   LDAP_BIND_DN / LDAP_BIND_PW   (service account for the search)
#   LDAP_TEST_USER (default "alice") + LDAP_TEST_USER_PW   -> in the allowed group
#   LDAP_TEST_OUTSIDER (default "bob") + LDAP_TEST_OUTSIDER_PW -> NOT in the group
#   (back-compat: LDAP_TEST_ALICE_PW / LDAP_TEST_BOB_PW are accepted)
# Optional AD-oriented checks (each runs only if its user ENV is present):
#   LDAP_TEST_NESTED_USER + LDAP_TEST_NESTED_PW  -> in the group only via a nested group
#   LDAP_TEST_DISABLED_USER + LDAP_TEST_DISABLED_PW -> a disabled directory account
if ENV['LDAP_INTEGRATION'] == 'true'
  describe 'LDAP login integration (live test directory)', type: :request do
    let(:callback) { '/auth/ldap/callback' }
    let(:user)        { ENV.fetch('LDAP_TEST_USER', 'alice') }
    let(:user_pw)     { ENV['LDAP_TEST_USER_PW'] || ENV.fetch('LDAP_TEST_ALICE_PW') }
    let(:outsider)    { ENV.fetch('LDAP_TEST_OUTSIDER', 'bob') }
    let(:outsider_pw) { ENV['LDAP_TEST_OUTSIDER_PW'] || ENV.fetch('LDAP_TEST_BOB_PW') }

    # A local Huginn account whose username matches the directory login name.
    def make_local_user(username)
      u = User.new(username: username, email: "#{username}@example.com")
      u.password = u.password_confirmation = SecureRandom.hex(16)
      u.requires_no_invitation_code!
      u.save!
      u
    end

    def login(username, password)
      post callback, params: { username: username, password: password }
    end

    it 'signs in a directory user in the allowed group (encrypted, with cert verification)' do
      local = make_local_user(user)
      login(user, user_pw)
      expect(response).to be_redirect
      expect(response.location).not_to include('/users/sign_in')
      expect(controller.current_user).to eq(local)
    end

    it 'rejects a wrong password' do
      make_local_user(user)
      login(user, 'definitely-the-wrong-password')
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects an empty password before any bind (middleware guard)' do
      login(user, '')
      expect(response).to be_redirect
      expect(response.location).to include('/users/sign_in')
    end

    it 'rejects a valid user who is NOT in the allowed group' do
      make_local_user(outsider)
      login(outsider, outsider_pw)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not sign in on a tokenless callback POST when forgery protection is on (login CSRF)' do
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      signed_in =
        begin
          login(user, user_pw) # request spec sends no authenticity token
          controller.respond_to?(:current_user) && controller.current_user.present?
        rescue ActionController::InvalidAuthenticityToken
          false
        ensure
          ActionController::Base.allow_forgery_protection = original
        end
      expect(signed_in).to be(false)
    end

    if ENV['LDAP_TEST_NESTED_USER']
      it 'signs in a user who is in the allowed group only via a nested group (LDAP_MATCHING_RULE_IN_CHAIN)' do
        nested = ENV.fetch('LDAP_TEST_NESTED_USER')
        local = make_local_user(nested)
        login(nested, ENV.fetch('LDAP_TEST_NESTED_PW'))
        expect(response).to be_redirect
        expect(response.location).not_to include('/users/sign_in')
        expect(controller.current_user).to eq(local)
      end
    end

    if ENV['LDAP_TEST_DISABLED_USER']
      it 'rejects a disabled directory account even with the correct password' do
        disabled = ENV.fetch('LDAP_TEST_DISABLED_USER')
        make_local_user(disabled)
        login(disabled, ENV.fetch('LDAP_TEST_DISABLED_PW'))
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
