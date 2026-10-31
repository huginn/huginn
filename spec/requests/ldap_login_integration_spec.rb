require 'rails_helper'

# End-to-end LDAP login against a live test directory. Opt-in only: it runs when
# LDAP_INTEGRATION=true AND the app was booted with the LDAP_* settings pointed
# at the test server (so the :ldap provider and its route exist). It never runs
# in the normal suite.
#
# Expected boot environment (set when invoking rspec):
#   LDAP_INTEGRATION=true
#   LDAP_HOST=<test server>  LDAP_BASE=ou=people,dc=example,dc=org  LDAP_UID=uid
#   LDAP_METHOD=tls  LDAP_CA_FILE=<ca.crt>   (proves encryption + cert verification)
#   LDAP_FILTER=(&(uid=%{username})(memberOf=cn=huginn-users,ou=groups,dc=example,dc=org))
#   LDAP_TEST_ALICE_PW / LDAP_TEST_BOB_PW : the test users' passwords
#   optionally LDAP_BIND_DN / LDAP_BIND_PW if the directory forbids anonymous search
if ENV['LDAP_INTEGRATION'] == 'true'
  describe 'LDAP login integration (live test directory)', type: :request do
    let(:alice_pw) { ENV.fetch('LDAP_TEST_ALICE_PW') }
    let(:bob_pw)   { ENV.fetch('LDAP_TEST_BOB_PW') }
    let(:callback) { '/auth/ldap/callback' }

    before do
      # A local Huginn account whose username matches the LDAP login name.
      @alice = User.new(username: 'alice', email: 'alice@example.com')
      @alice.password = @alice.password_confirmation = SecureRandom.hex(16)
      @alice.requires_no_invitation_code!
      @alice.save!
    end

    def login(username, password)
      post callback, params: { username: username, password: password }
    end

    it 'signs in a directory user who is in the allowed group (alice, over StartTLS with cert verification)' do
      login('alice', alice_pw)
      expect(response).to be_redirect
      expect(response.location).not_to include('/users/sign_in')
      expect(controller.current_user).to eq(@alice)
    end

    it 'rejects a wrong password' do
      login('alice', 'definitely-the-wrong-password')
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects an empty password before any bind (middleware guard)' do
      login('alice', '')
      expect(response).to be_redirect
      expect(response.location).to include('/users/sign_in')
    end

    it 'rejects a valid user who is NOT in the allowed group (bob)' do
      login('bob', bob_pw)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not sign in on a tokenless callback POST when forgery protection is on (login CSRF)' do
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      signed_in =
        begin
          login('alice', alice_pw) # request spec sends no authenticity token
          controller.respond_to?(:current_user) && controller.current_user.present?
        rescue ActionController::InvalidAuthenticityToken
          false
        ensure
          ActionController::Base.allow_forgery_protection = original
        end
      expect(signed_in).to be(false)
    end
  end
end
