require 'rails_helper'
require 'rack/mock'
require 'rack/ldap_credentials_guard'

describe Rack::LdapCredentialsGuard do
  let(:path) { '/auth/ldap/callback' }
  let(:downstream_calls) { [] }
  let(:downstream) { ->(env) { downstream_calls << env; [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:app) { described_class.new(downstream, path: path) }

  def post(target, params)
    app.call(Rack::MockRequest.env_for(target, method: 'POST', params: params))
  end

  it 'rejects a blank password before the request reaches the strategy' do
    status, headers, = post(path, 'username' => 'alice', 'password' => '')
    expect(status).to eq(302)
    expect(headers['Location']).to eq('/users/sign_in')
    expect(downstream_calls).to be_empty
  end

  it 'rejects a whitespace-only username or password (the strategy only checks .empty?)' do
    expect(post(path, 'username' => '   ', 'password' => 'secret').first).to eq(302)
    expect(post(path, 'username' => 'alice', 'password' => '   ').first).to eq(302)
    expect(downstream_calls).to be_empty
  end

  it 'passes a request that has both credentials through to the strategy' do
    status, = post(path, 'username' => 'alice', 'password' => 'secret')
    expect(status).to eq(200)
    expect(downstream_calls.size).to eq(1)
  end

  it 'ignores other paths and non-POST requests' do
    post('/some/other/path', 'username' => '', 'password' => '')
    app.call(Rack::MockRequest.env_for(path, method: 'GET'))
    expect(downstream_calls.size).to eq(2)
  end
end
