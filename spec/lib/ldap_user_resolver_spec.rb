require 'rails_helper'
require 'ldap_user_resolver'

describe LdapUserResolver do
  def with_env(vars)
    saved = {}
    vars.each do |key, value|
      saved[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  # Build an OmniAuth auth hash as omniauth-ldap produces it: info.nickname
  # carries the login attribute value, the raw entry sits under extra.raw_info,
  # and auth.uid is the DN (mapping "uid" => "dn").
  def auth_hash(uid_value:, email: nil, nickname: :same)
    nickname = uid_value if nickname == :same
    OmniAuth::AuthHash.new(
      'provider' => 'ldap',
      'uid' => "uid=#{uid_value},ou=people,dc=example,dc=org",
      'info' => { 'email' => email, 'nickname' => nickname },
      'extra' => { 'raw_info' => { 'uid' => Array(uid_value) } }
    )
  end

  describe '.extract_username' do
    it 'reads the login name from info.nickname, never the email' do
      auth = auth_hash(uid_value: 'alice', email: 'someone.else@example.com')
      expect(described_class.extract_username(auth)).to eq('alice')
    end

    it 'falls back to the raw uid attribute when nickname is absent' do
      auth = auth_hash(uid_value: 'alice', nickname: nil)
      expect(described_class.extract_username(auth)).to eq('alice')
    end

    it 'is blank for a nil auth' do
      expect(described_class.extract_username(nil)).to eq('')
    end
  end

  describe '.resolve' do
    it 'returns the local user whose username matches' do
      expect(described_class.resolve(auth_hash(uid_value: 'bob'))).to eq(users(:bob))
    end

    it 'never links by email: an LDAP email matching a local account does not log that account in' do
      # LDAP username "ghost" has no local account, but carries bob's email.
      auth = auth_hash(uid_value: 'ghost', email: users(:bob).email)
      with_env('LDAP_AUTO_CREATE' => nil) do
        expect(described_class.resolve(auth)).to be_nil
      end
    end

    it 'rejects an unknown user when auto-create is off (the default)' do
      with_env('LDAP_AUTO_CREATE' => nil) do
        expect(described_class.resolve(auth_hash(uid_value: 'nobody'))).to be_nil
      end
    end

    it 'provisions a new local user only when auto-create is enabled' do
      auth = auth_hash(uid_value: 'newperson', email: 'newperson@example.com')
      with_env('LDAP_AUTO_CREATE' => 'true') do
        expect { @user = described_class.resolve(auth) }.to change(User, :count).by(1)
        expect(@user.username).to eq('newperson')
      end
    end
  end
end
