require 'rails_helper'
require 'ldap_settings'

describe LdapSettings do
  # Set the given environment variables for the duration of the block and
  # restore the previous values afterwards.
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

  describe '.enabled?' do
    it 'is off when LDAP_HOST is unset or blank' do
      with_env('LDAP_HOST' => nil) { expect(described_class).not_to be_enabled }
      with_env('LDAP_HOST' => '  ') { expect(described_class).not_to be_enabled }
    end

    it 'is on when LDAP_HOST is set' do
      with_env('LDAP_HOST' => 'ldap.example.org') { expect(described_class).to be_enabled }
    end
  end

  describe '.method / .encrypted?' do
    it 'defaults to encrypted StartTLS, never clear text' do
      with_env('LDAP_METHOD' => nil) do
        expect(described_class.method).to eq(:tls)
        expect(described_class).to be_encrypted
      end
    end

    it 'uses clear text only when explicitly requested' do
      with_env('LDAP_METHOD' => 'plain') do
        expect(described_class.method).to eq(:plain)
        expect(described_class).not_to be_encrypted
      end
    end

    it 'rejects an unknown method' do
      with_env('LDAP_METHOD' => 'bogus') do
        expect { described_class.method }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.port' do
    it 'defaults to 389 for StartTLS/plain and 636 for LDAPS' do
      with_env('LDAP_PORT' => nil, 'LDAP_METHOD' => 'tls') { expect(described_class.port).to eq(389) }
      with_env('LDAP_PORT' => nil, 'LDAP_METHOD' => 'ssl') { expect(described_class.port).to eq(636) }
    end

    it 'honours an explicit port' do
      with_env('LDAP_PORT' => '1389') { expect(described_class.port).to eq(1389) }
    end
  end

  describe '.verify_certificates? / .auto_create?' do
    it 'verifies certificates by default' do
      with_env('LDAP_DISABLE_VERIFY_CERTIFICATES' => nil) { expect(described_class).to be_verify_certificates }
    end

    it 'only disables verification on an explicit opt-out' do
      with_env('LDAP_DISABLE_VERIFY_CERTIFICATES' => 'true') { expect(described_class).not_to be_verify_certificates }
    end

    it 'does not auto-create accounts by default' do
      with_env('LDAP_AUTO_CREATE' => nil) { expect(described_class).not_to be_auto_create }
      with_env('LDAP_AUTO_CREATE' => 'true') { expect(described_class).to be_auto_create }
    end
  end

  describe '.omniauth_options' do
    it 'requires a base DN when enabled' do
      with_env('LDAP_HOST' => 'ldap.example.org', 'LDAP_BASE' => nil) do
        expect { described_class.omniauth_options }.to raise_error(/LDAP_BASE/)
      end
    end

    it 'builds encrypted options with certificate verification by default' do
      with_env('LDAP_HOST' => 'ldap.example.org', 'LDAP_BASE' => 'dc=example,dc=org',
               'LDAP_METHOD' => nil, 'LDAP_UID' => nil, 'LDAP_DISABLE_VERIFY_CERTIFICATES' => nil) do
        opts = described_class.omniauth_options
        expect(opts[:method]).to eq(:tls)
        expect(opts[:uid]).to eq('uid')
        # false => omniauth-ldap verifies against the system trust store
        expect(opts[:disable_verify_certificates]).to eq(false)
      end
    end

    it 'passes a custom CA file through and can disable verification explicitly' do
      with_env('LDAP_HOST' => 'ldap.example.org', 'LDAP_BASE' => 'dc=example,dc=org',
               'LDAP_CA_FILE' => '/etc/ssl/ldap-ca.crt', 'LDAP_DISABLE_VERIFY_CERTIFICATES' => 'true') do
        opts = described_class.omniauth_options
        expect(opts[:disable_verify_certificates]).to eq(true)
        expect(opts[:tls_options]).to eq(ca_file: '/etc/ssl/ldap-ca.crt')
      end
    end

    it 'passes a group/search filter through when configured' do
      with_env('LDAP_HOST' => 'ldap.example.org', 'LDAP_BASE' => 'dc=example,dc=org',
               'LDAP_FILTER' => '(&(uid=%{username})(memberOf=cn=huginn-users,ou=groups,dc=example,dc=org))') do
        expect(described_class.omniauth_options[:filter]).to include('memberOf=cn=huginn-users')
      end
    end

    it 'omits TLS options and does not verify certificates in clear-text mode' do
      with_env('LDAP_HOST' => 'ldap.example.org', 'LDAP_BASE' => 'dc=example,dc=org', 'LDAP_METHOD' => 'plain') do
        opts = described_class.omniauth_options
        expect(opts[:method]).to eq(:plain)
        expect(opts).not_to have_key(:tls_options)
      end
    end
  end
end
